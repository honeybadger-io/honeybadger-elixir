defmodule Honeybadger.EventsWorker do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :backend,
      :batch_size,
      :max_queue_size,
      :timeout,
      :timer_ref,
      :max_batch_retries,
      # Are we currently throttling?
      throttling: false,
      # 1 minute default wait time for throttled requests
      throttle_wait: 60000,
      dropped_events: 0,
      queue: [],
      batches: []
    ]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def push(event), do: GenServer.cast(__MODULE__, {:push, event})
  def state, do: GenServer.call(__MODULE__, {:state})

  @impl true
  def init(opts) do
    state = struct!(State, Map.new(opts))
    timer_ref = schedule_flush(state)
    {:ok, %{state | timer_ref: timer_ref}}
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
  def handle_info(:flush, %State{batches: [], queue: []} = state) do
    {:noreply, %{state | timer_ref: schedule_flush(state)}}
  end

  @impl true
  def handle_info(:flush, %State{queue: []} = state) do
    {:noreply, attempt_send(state)}
  end

  @impl true
  def handle_info(:flush, %State{queue: queue} = state) do
    batches = state.batches ++ [%{batch: Enum.reverse(queue), attempts: 0}]
    {:noreply, attempt_send(%{state | queue: [], batches: batches})}
  end

  @impl true
  def terminate(_reason, %State{timer_ref: timer_ref} = state) do
    if timer_ref, do: Process.cancel_timer(timer_ref)

    Logger.debug("Terminating with #{total_event_count(state)} events unsent")

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

  # Skip reseting flush if we are throttling
  defp schedule_flush(%State{timer_ref: timer_ref, throttling: true}) do
    timer_ref
  end

  defp schedule_flush(%State{timer_ref: timer_ref, timeout: timeout}) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
    Process.send_after(self(), :flush, timeout)
  end

  # Attempt sending each batch in order. If we get a 429, set backoff_until and
  # immediately stop sending further batches. If any other error, retry up to
  # max_batch_retries, then drop it.
  defp attempt_send(%State{timer_ref: timer_ref} = state) do
    if timer_ref, do: Process.cancel_timer(timer_ref)

    {new_batches, throttling} =
      Enum.reduce(state.batches, {[], nil}, fn %{batch: batch, attempts: attempts} = b,
                                               {acc, throttling} ->
        # If we already decided to back off this round, just keep the rest
        if throttling do
          {acc ++ [b], throttling}
        else
          case state.backend.send_events(batch) do
            :ok ->
              Logger.debug("Sent batch of #{length(batch)} events.")
              {acc, nil}

            {:error, :throttled} ->
              # If 429, set backoff and keep this batch (no attempts increment).
              Logger.warning("Rate limited (429) - waiting for #{state.throttle_wait}ms")
              {acc ++ [b], true}

            {:error, reason} ->
              Logger.debug("Failed to send batch (attempt #{attempts + 1}): #{inspect(reason)}")
              updated_attempts = attempts + 1

              if updated_attempts < state.max_batch_retries do
                # Keep batch, increment attempts
                {acc ++ [%{b | attempts: updated_attempts}], nil}
              else
                Logger.debug("Dropping batch after #{updated_attempts} attempts.")
                {acc, nil}
              end
          end
        end
      end)

    timer_ref =
      Process.send_after(
        self(),
        :flush,
        if(throttling, do: state.throttle_wait, else: state.timeout)
      )

    %{state | batches: new_batches, throttling: throttling, timer_ref: timer_ref}
  end

  defp total_event_count(%State{batches: batches, queue: queue}) do
    events_count = length(queue)
    batch_count = Enum.reduce(batches, 0, fn %{batch: b}, acc -> acc + length(b) end)
    events_count + batch_count
  end
end
