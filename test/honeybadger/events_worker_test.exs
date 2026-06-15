defmodule Honeybadger.EventsWorkerTest do
  use Honeybadger.Case, async: true
  require Logger

  alias Honeybadger.EventsWorker

  defp start_worker(config) do
    name =
      "test_events_worker_#{System.unique_integer([:positive])}"
      |> String.to_atom()

    EventsWorker.start_link(config ++ [name: name])
  end

  # Total events the worker is currently holding, across the pending queue and
  # all not-yet-acknowledged batches.
  defp queued_event_count(state) do
    batch_events =
      state.batches
      |> :queue.to_list()
      |> Enum.reduce(0, fn %{batch: batch}, acc -> acc + length(batch) end)

    length(state.queue) + batch_events
  end

  setup do
    {:ok, behavior_agent} = Agent.start_link(fn -> :ok end)

    test_pid = self()

    send_events_fn = fn events ->
      send(test_pid, {:events_sent, events})

      case Agent.get(behavior_agent, & &1) do
        :ok -> :ok
        :throttle -> {:error, :throttled}
        :error -> {:error, "Other error"}
      end
    end

    change_behavior = fn new_behavior ->
      Agent.update(behavior_agent, fn _ -> new_behavior end)
    end

    # Common test configuration
    config = [
      send_events_fn: send_events_fn,
      batch_size: 3,
      max_batch_retries: 2,
      max_queue_size: 10,
      timeout: 100
    ]

    {:ok, config: config, change_behavior: change_behavior}
  end

  describe "batch size triggering" do
    test "sends events when batch size is reached", %{config: config} do
      {:ok, pid} = start_worker(config)
      events = [%{id: 1}, %{id: 2}, %{id: 3}]
      Enum.each(events, &EventsWorker.push(&1, pid))
      GenServer.stop(pid)

      assert_receive {:events_sent, ^events}, 50
    end

    test "queues events when under batch size", %{config: config} do
      {:ok, pid} = start_worker(config)

      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1, pid))
      refute_receive {:events_sent, _}, 50

      GenServer.stop(pid)
    end
  end

  describe "max_queue_size" do
    test "drops events from queue", %{config: config, change_behavior: change_behavior} do
      {:ok, pid} =
        start_worker(Keyword.merge(config, timeout: 5000, max_queue_size: 4))

      change_behavior.(:error)
      events = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}, %{id: 6}]
      Enum.each(events, &EventsWorker.push(&1, pid))

      state = EventsWorker.state(pid)

      assert state.dropped_events == 2
      assert state.queue == [%{id: 4}]

      assert :queue.to_list(state.batches) == [
               %{attempts: 1, batch: [%{id: 1}, %{id: 2}, %{id: 3}]}
             ]

      GenServer.stop(pid)
    end
  end

  describe "timer triggering" do
    test "flushes events when timer expires", %{config: config} do
      {:ok, pid} = start_worker(config)
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^events}, config[:timeout] + 50
      GenServer.stop(pid)
    end

    test "resets timer when batch is sent", %{config: config} do
      # Larger flush timeout so the "before vs after the timer" windows have
      # comfortable margins and don't race the worker under load.
      config = Keyword.merge(config, timeout: 200)
      {:ok, pid} = start_worker(config)

      first_batch = [%{id: 1}, %{id: 2}, %{id: 3}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))
      # A full batch flushes immediately.
      assert_receive {:events_sent, ^first_batch}, 100

      second_batch = [%{id: 4}, %{id: 5}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))
      # The timer was reset by the flush, so a partial batch must not flush early...
      refute_receive {:events_sent, _}, div(config[:timeout], 2)
      # ...but does flush once the full timeout elapses.
      assert_receive {:events_sent, ^second_batch}, config[:timeout]

      GenServer.stop(pid)
    end
  end

  describe "error handling" do
    setup %{config: config} do
      config =
        Keyword.merge(config,
          batch_size: 2,
          timeout: 100,
          throttle_wait: 300,
          max_queue_size: 10000
        )

      {:ok, config: config}
    end

    test "retries and drops after max attempts", %{
      config: config,
      change_behavior: change_behavior
    } do
      config = Keyword.merge(config, max_batch_retries: 3)

      {:ok, pid} = start_worker(config)

      # Start with error behavior
      change_behavior.(:error)

      # Send enough events to trigger a batch
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1, pid))

      # The batch is attempted exactly max_batch_retries times. Each retry waits
      # one flush `timeout`, so give each attempt a generous window rather than a
      # single tight cumulative deadline.
      for _attempt <- 1..config[:max_batch_retries] do
        assert_receive {:events_sent, ^events}, config[:timeout] + 200
      end

      # After the final failed attempt the batch is dropped and not retried again.
      assert eventually(fn -> :queue.is_empty(EventsWorker.state(pid).batches) end)
      refute_receive {:events_sent, ^events}, config[:timeout] + 100

      GenServer.stop(pid)
    end

    test "queues new events during retry attempts", %{
      config: config,
      change_behavior: change_behavior
    } do
      # Plenty of retry budget so the failing batch is not dropped before the
      # backend recovers.
      config = Keyword.merge(config, max_batch_retries: 10)
      {:ok, pid} = start_worker(config)

      change_behavior.(:error)

      # First batch fills batch_size and is attempted, but the backend errors, so
      # it stays queued for retry.
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^first_batch}, 200

      # Queue new events during the retry window. Polling on the synchronous
      # state/1 call barriers all pushes through before we let the backend
      # recover, removing the cast/Agent race that made this test flaky.
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))
      assert eventually(fn -> queued_event_count(EventsWorker.state(pid)) == 4 end)

      # Switch to success. Both batches should drain. assert_receive does a
      # selective receive, so we don't depend on exact ordering or on
      # intermediate failed-retry emissions.
      change_behavior.(:ok)

      assert_receive {:events_sent, ^first_batch}, config[:timeout] + 500
      assert_receive {:events_sent, ^second_batch}, config[:timeout] + 500

      assert eventually(fn -> :queue.is_empty(EventsWorker.state(pid).batches) end)

      GenServer.stop(pid)
    end

    test "does not reset flush timer on subsequent pushes", %{config: config} do
      # batch_size high so only the flush timer triggers sends; larger timeout
      # for comfortable margins.
      config = Keyword.merge(config, timeout: 200, batch_size: 1000)
      {:ok, pid} = start_worker(config)

      # Push id1 (starts the flush timer), then id2 well within the timer window.
      EventsWorker.push(%{id: 1}, pid)
      :timer.sleep(div(config[:timeout], 4))
      EventsWorker.push(%{id: 2}, pid)

      # The second push does not reset the timer, so both flush together when the
      # original timer expires.
      assert_receive {:events_sent, [%{id: 1}, %{id: 2}]}, config[:timeout]

      # A push after that flush starts a fresh timer and flushes on its own.
      EventsWorker.push(%{id: 3}, pid)
      assert_receive {:events_sent, [%{id: 3}]}, config[:timeout] + 200

      GenServer.stop(pid)
    end

    test "works with pushes after a flush", %{config: config} do
      config = Keyword.merge(config, timeout: 100, batch_size: 1000)
      {:ok, pid} = start_worker(config)

      # First event flushes on its own timer.
      EventsWorker.push(%{id: 1}, pid)
      assert_receive {:events_sent, [%{id: 1}]}, config[:timeout] + 200

      # A push after that flush starts a fresh timer: it must not flush
      # immediately, but does once the new timeout elapses.
      EventsWorker.push(%{id: 2}, pid)
      refute_receive {:events_sent, [%{id: 2}]}, div(config[:timeout], 2)
      assert_receive {:events_sent, [%{id: 2}]}, config[:timeout] + 200

      GenServer.stop(pid)
    end

    test "handles throttling and resumes after wait period", %{
      config: config,
      change_behavior: change_behavior
    } do
      {:ok, pid} = start_worker(config)

      # Start with throttle behavior
      change_behavior.(:throttle)

      # First batch fills batch_size and is attempted, but the backend throttles
      # it, so it stays queued.
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^first_batch}, 200

      # Wait until the worker has recorded the throttle before continuing.
      assert eventually(fn -> EventsWorker.state(pid).throttling end)

      # Queue a second batch while still throttled. state/1 is a synchronous
      # call, so polling on it acts as a barrier: all preceding async pushes are
      # guaranteed processed (and both batches queued) before we flip the backend
      # to :ok. This removes the cast/Agent race that made this test flaky. The
      # throttled batch is banked, not retried early, so the default retry budget
      # is plenty.
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))
      assert eventually(fn -> queued_event_count(EventsWorker.state(pid)) == 4 end)

      # Backend recovers. Once throttle_wait elapses, both batches should be
      # delivered. assert_receive does a selective receive, so we don't depend on
      # exact ordering.
      change_behavior.(:ok)

      assert_receive {:events_sent, ^first_batch}, config[:throttle_wait] + 500
      assert_receive {:events_sent, ^second_batch}, config[:throttle_wait] + 500

      # Nothing is left queued once the backend has recovered.
      assert eventually(fn -> :queue.is_empty(EventsWorker.state(pid).batches) end)

      GenServer.stop(pid)
    end

    test "flush delay respects throttle_wait when throttled", %{
      config: config,
      change_behavior: change_behavior
    } do
      # Set small values for quick testing.
      config = Keyword.merge(config, batch_size: 2, timeout: 100, throttle_wait: 300)
      {:ok, pid} = start_worker(config)

      change_behavior.(:throttle)

      # Push a batch to trigger throttling.
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^events}, 50

      # Verify throttling is active.
      state = EventsWorker.state(pid)
      assert state.throttling == true

      start_time = System.monotonic_time(:millisecond)

      # Wait less than throttle_wait to ensure no flush occurs.
      refute_receive {:events_sent, _}, 250

      # Switch backend to success so the retry flush can go through.
      change_behavior.(:ok)

      # The retry flush should occur after throttle_wait (300ms).
      assert_receive {:events_sent, ^events}, 150

      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed >= 300

      GenServer.stop(pid)
    end

    test "does not retry a throttled batch early when new events arrive", %{
      config: config,
      change_behavior: change_behavior
    } do
      # Large timeout so only the throttle backoff (throttle_wait) governs the
      # retry timing during this test.
      config = Keyword.merge(config, batch_size: 2, throttle_wait: 300, timeout: 1000)
      {:ok, pid} = start_worker(config)

      change_behavior.(:throttle)

      # First batch is attempted and throttled, so it stays queued.
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^first_batch}, 200
      # state/1 is synchronous, so this also barriers the throttle result through.
      assert EventsWorker.state(pid).throttling

      # New events fill another batch while still throttled.
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))

      # The throttled batch must NOT be retried just because new events arrived:
      # its attempt count stays at 1 and the new batch is banked behind it. A
      # retry here would hammer the rate-limited backend and burn the retry
      # budget. Asserting on state is timing-independent, unlike a refute_receive
      # window that would race the throttle_wait timer under load.
      state = EventsWorker.state(pid)

      assert :queue.to_list(state.batches) == [
               %{batch: first_batch, attempts: 1},
               %{batch: second_batch, attempts: 0}
             ]

      # Once the backend recovers, the timer-driven retry (after throttle_wait)
      # drains both batches without dropping anything.
      change_behavior.(:ok)
      assert_receive {:events_sent, ^first_batch}, config[:throttle_wait] + 500
      assert_receive {:events_sent, ^second_batch}, config[:throttle_wait] + 500

      GenServer.stop(pid)
    end
  end

  describe "termination" do
    test "sends remaining events on termination", %{config: config} do
      {:ok, pid} = start_worker(config)
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^events}, 500

      GenServer.stop(pid)
    end
  end
end
