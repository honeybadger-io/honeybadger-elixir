defmodule Honeybadger.EventsWorker do
  @moduledoc """
  A GenServer that batches and sends events with retry and throttling logic.

  It accumulates events in a queue, forms batches when the batch size is reached or
  when a flush timeout expires, and then sends these batches to a backend module.
  If a batch fails to send, it will be retried (up to a configurable maximum) or dropped.
  In case of throttling (e.g. receiving a 429), the flush delay is increased.
  """

  @dropped_log_interval 60_000

  use GenServer
  require Logger

  defmodule State do
    @typedoc """
    Function that accepts a list of events to be processed.
    """
    @type send_events_fn :: ([term()] -> :ok | {:error, :throttled} | {:error, term()})

    @typedoc """
    State for the event batching GenServer.
    """
    @type t :: %__MODULE__{
            # Configuration
            send_events_fn: send_events_fn(),
            batch_size: pos_integer(),
            max_queue_size: pos_integer(),
            timeout: pos_integer(),
            max_batch_retries: non_neg_integer(),
            throttle_wait: pos_integer(),

            # Internal state
            timeout_started_at: non_neg_integer(),
            throttling: boolean(),
            dropped_events: non_neg_integer(),
            last_dropped_log: non_neg_integer(),
            queue: [any()],
            batches: :queue.queue()
          }

    @enforce_keys [
      :send_events_fn,
      :batch_size,
      :max_queue_size,
      :max_batch_retries
    ]

    defstruct [
      :send_events_fn,
      :batch_size,
      :max_queue_size,
      :timeout,
      :max_batch_retries,
      :last_dropped_log,
      timeout_started_at: 0,
      throttle_wait: 60000,
      throttling: false,
      dropped_events: 0,
      queue: [],
      batches: :queue.new()
    ]
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    if Honeybadger.get_env(:events_worker_enabled) do
      {name, opts} = Keyword.pop(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      :ignore
    end
  end

  @spec push(event :: map(), GenServer.server()) :: :ok
  def push(event, server \\ __MODULE__) do
    GenServer.cast(server, {:push, event})
  end

  @spec state(GenServer.server()) :: State.t()
  def state(server \\ __MODULE__) do
    GenServer.call(server, {:state})
  end

  @impl true
  def init(opts) do
    config = %{
      send_events_fn: Keyword.get(opts, :send_events_fn, &Honeybadger.Client.send_events/1),
      batch_size: Keyword.get(opts, :batch_size, Honeybadger.get_env(:events_batch_size)),
      timeout: Keyword.get(opts, :timeout, Honeybadger.get_env(:events_timeout)),
      throttle_wait:
        Keyword.get(opts, :throttle_wait, Honeybadger.get_env(:events_throttle_wait)),
      max_queue_size:
        Keyword.get(opts, :max_queue_size, Honeybadger.get_env(:events_max_queue_size)),
      max_batch_retries:
        Keyword.get(opts, :max_batch_retries, Honeybadger.get_env(:events_max_batch_retries)),
      last_dropped_log: System.monotonic_time(:millisecond)
    }

    state = struct!(State, config)
    {:ok, state}
  end

  @impl true
  def handle_call({:state}, _from, %State{} = state) do
    {:reply, state, state, current_timeout(state)}
  end

  @impl true
  def handle_cast({:push, event}, %State{timeout_started_at: 0} = state) do
    handle_cast({:push, event}, reset_timeout(state))
  end

  def handle_cast({:push, event}, %State{} = state) do
    if total_event_count(state) >= state.max_queue_size do
      {:noreply, %{state | dropped_events: state.dropped_events + 1}, current_timeout(state)}
    else
      queue = [event | state.queue]

      if length(queue) >= state.batch_size do
        flush(%{state | queue: queue})
      else
        {:noreply, %{state | queue: queue}, current_timeout(state)}
      end
    end
  end

  @impl true
  def handle_info(:timeout, state), do: flush(state)

  @impl true
  def terminate(_reason, %State{} = state) do
    Logger.debug("[Honeybadger] Terminating with #{total_event_count(state)} events unsent")
    _ = flush(state)
    :ok
  end

  @spec flush(State.t()) :: {:noreply, State.t(), pos_integer()}
  defp flush(state) do
    cond do
      state.queue == [] and :queue.is_empty(state.batches) ->
        # It's all empty so we stop the timeout and reset the
        # timeout_started_at which will restart on the next push
        {:noreply, %{state | timeout_started_at: 0}}

      state.queue == [] ->
        attempt_send(state)

      true ->
        batches = :queue.in(%{batch: Enum.reverse(state.queue), attempts: 0}, state.batches)
        attempt_send(%{state | queue: [], batches: batches})
    end
  end

  @spec attempt_send(State.t()) :: {:noreply, State.t(), pos_integer()}
  # Sends pending batches, handling retries and throttling
  defp attempt_send(%State{} = state) do
    {new_batches_list, throttling} =
      Enum.reduce(:queue.to_list(state.batches), {[], false}, fn
        # If already throttled, skip sending and retain the batch.
        b, {acc, true} ->
          {acc ++ [b], true}

        %{batch: batch, attempts: attempts} = b, {acc, false} ->
          case state.send_events_fn.(batch) do
            :ok ->
              {acc, false}

            {:error, reason} ->
              throttling = reason == :throttled
              updated_attempts = attempts + 1

              if throttling do
                Logger.warning(
                  "[Honeybadger] Rate limited (429) events - (batch attempt #{updated_attempts}) - waiting for #{state.throttle_wait}ms"
                )
              else
                Logger.debug(
                  "[Honeybadger] Failed to send events batch (attempt #{updated_attempts}): #{inspect(reason)}"
                )
              end

              if updated_attempts < state.max_batch_retries do
                {acc ++ [%{b | attempts: updated_attempts}], throttling}
              else
                Logger.debug(
                  "[Honeybadger] Dropping events batch after #{updated_attempts} attempts."
                )

                {acc, throttling}
              end
          end
      end)

    current_time = System.monotonic_time(:millisecond)

    # Log dropped events if present and we haven't logged within the last
    # @dropped_log_interval
    state =
      if state.dropped_events > 0 and
           current_time - state.last_dropped_log >= @dropped_log_interval do
        Logger.info("[Honeybadger] Dropped #{state.dropped_events} events due to max queue limit")
        %{state | dropped_events: 0, last_dropped_log: current_time}
      else
        state
      end

    new_state =
      %{state | batches: :queue.from_list(new_batches_list), throttling: throttling}
      |> reset_timeout()

    {:noreply, new_state, current_timeout(new_state)}
  end

  @spec total_event_count(State.t()) :: non_neg_integer()
  # Counts events in both the queue and pending batches.
  defp total_event_count(%State{batches: batches, queue: queue}) do
    events_count = length(queue)

    batch_count = :queue.fold(fn %{batch: b}, acc -> acc + length(b) end, 0, batches)

    events_count + batch_count
  end

  # Returns the time remaining until the next flush
  defp current_timeout(%State{
         throttling: throttling,
         timeout: timeout,
         throttle_wait: throttle_wait,
         timeout_started_at: timeout_started_at
       }) do
    elapsed = System.monotonic_time(:millisecond) - timeout_started_at
    timeout = if throttling, do: throttle_wait, else: timeout
    max(1, timeout - elapsed)
  end

  defp reset_timeout(state) do
    %{state | timeout_started_at: System.monotonic_time(:millisecond)}
  end
end
