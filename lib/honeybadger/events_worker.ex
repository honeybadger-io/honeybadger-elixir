defmodule Honeybadger.EventsWorker do
  @dropped_log_interval 60_000

  @moduledoc """
  A GenServer that batches and sends events with retry and throttling logic.

  It accumulates events in a queue, forms batches when the batch size is reached or
  when a flush timeout expires, and then sends these batches to a backend module.
  If a batch fails to send, it will be retried (up to a configurable maximum) or dropped.
  In case of throttling (e.g. receiving a 429), the flush delay is increased.
  """

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
            timer_ref: reference() | nil,
            throttling: boolean(),
            dropped_events: non_neg_integer(),
            queue: [term()],
            last_dropped_log: non_neg_integer(),
            batches: [[term()]]
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
      :timer_ref,
      :last_dropped_log,
      throttle_wait: 60000,
      throttling: false,
      dropped_events: 0,
      queue: [],
      batches: []
    ]
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, Keyword.drop(opts, [:name]), name: name)
  end

  @spec push(event :: map(), server :: pid() | atom()) :: :ok
  def push(event, server \\ __MODULE__) do
    GenServer.cast(server, {:push, event})
  end

  @spec state(server :: pid() | atom()) :: __MODULE__.State.t()
  def state(server \\ __MODULE__) do
    GenServer.call(server, {:state})
  end

  @impl true
  def init(opts) do
    state = struct!(State, Map.new(opts))
    timer_ref = schedule_flush(state)
    {:ok, %{state | timer_ref: timer_ref, last_dropped_log: System.monotonic_time(:millisecond)}}
  end

  @impl true
  def handle_call({:state}, _from, %State{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:push, event}, %State{} = state) do
    if total_event_count(state) >= state.max_queue_size do
      {:noreply, %{state | dropped_events: state.dropped_events + 1}}
    else
      queue = [event | state.queue]

      if length(queue) >= state.batch_size do
        batches = state.batches ++ [%{batch: Enum.reverse(queue), attempts: 0}]
        state = attempt_send(%{state | queue: [], batches: batches})
        {:noreply, state}
      else
        {:noreply, %{state | queue: queue}}
      end
    end
  end

  @impl true
  # With empty batches and queue just reschedule another flush
  def handle_info(:flush, %State{batches: [], queue: []} = state) do
    {:noreply, %{state | timer_ref: schedule_flush(state)}}
  end

  @impl true
  # With an empty queue, just attempt to send the batches
  def handle_info(:flush, %State{queue: []} = state) do
    {:noreply, attempt_send(state)}
  end

  @impl true
  # Flush the queue into a new batch and attempt to send it
  def handle_info(:flush, %State{queue: queue} = state) do
    batches = state.batches ++ [%{batch: Enum.reverse(queue), attempts: 0}]
    {:noreply, attempt_send(%{state | queue: [], batches: batches})}
  end

  @impl true
  def terminate(_reason, %State{timer_ref: timer_ref} = state) do
    if timer_ref, do: Process.cancel_timer(timer_ref)

    Logger.debug("[Honeybadger] Terminating with #{total_event_count(state)} events unsent")

    # Best effort final flush (inline)
    final_state =
      if state.queue != [] do
        batch = %{batch: Enum.reverse(state.queue), attempts: 0}
        %{state | queue: [], batches: state.batches ++ [batch]}
      else
        state
      end

    _ = attempt_send(final_state)

    :ok
  end

  @spec schedule_flush(State.t()) :: reference() | nil
  # Schedules a flush timer (or reuses the current one when throttled with no
  # new events).
  defp schedule_flush(%State{timer_ref: timer_ref, throttling: true}), do: timer_ref

  defp schedule_flush(%State{timer_ref: timer_ref, timeout: timeout}) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
    Process.send_after(self(), :flush, timeout)
  end

  @spec attempt_send(State.t()) :: State.t()
  # Sends pending batches, handling retries and throttling, and schedules the
  # next flush.
  defp attempt_send(%State{timer_ref: timer_ref} = state) do
    if timer_ref, do: Process.cancel_timer(timer_ref)

    {new_batches, throttling} =
      Enum.reduce(state.batches, {[], nil}, fn
        # If already throttled, skip sending and retain the batch.
        b, {acc, true} ->
          {acc ++ [b], true}

        %{batch: batch, attempts: attempts} = b, {acc, nil} ->
          case state.send_events_fn.(batch) do
            :ok ->
              Logger.debug("[Honeybadger] Sent batch of #{length(batch)} events.")
              {acc, nil}

            {:error, :throttled} ->
              Logger.warning(
                "[Honeybadger] Rate limited (429) events - waiting for #{state.throttle_wait}ms"
              )

              {acc ++ [b], true}

            {:error, reason} ->
              Logger.debug(
                "[Honeybadger] Failed to send events batch (attempt #{attempts + 1}): #{inspect(reason)}"
              )

              updated_attempts = attempts + 1

              if updated_attempts < state.max_batch_retries do
                {acc ++ [%{b | attempts: updated_attempts}], nil}
              else
                Logger.debug(
                  "[Honeybadger] Dropping events batch after #{updated_attempts} attempts."
                )

                {acc, nil}
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

    timer_ref =
      Process.send_after(
        self(),
        :flush,
        if(throttling, do: state.throttle_wait, else: state.timeout)
      )

    %{state | batches: new_batches, throttling: throttling, timer_ref: timer_ref}
  end

  @spec total_event_count(State.t()) :: non_neg_integer()
  # Counts events in both the queue and pending batches.
  defp total_event_count(%State{batches: batches, queue: queue}) do
    events_count = length(queue)
    batch_count = Enum.reduce(batches, 0, fn %{batch: b}, acc -> acc + length(b) end)
    events_count + batch_count
  end
end
