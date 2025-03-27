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
      {:ok, pid} = start_worker(config)

      first_batch = [%{id: 1}, %{id: 2}, %{id: 3}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))
      assert_receive {:events_sent, ^first_batch}, 50

      second_batch = [%{id: 4}, %{id: 5}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))
      refute_receive {:events_sent, _}, 50
      assert_receive {:events_sent, ^second_batch}, 100

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

      # Wait for first attempt
      assert_receive {:events_sent, ^events}, 50

      # Should retry after timeout
      assert_receive {:events_sent, ^events}, 150

      # Should retry one more time and then drop
      assert_receive {:events_sent, ^events}, 250

      # Check final state
      state = EventsWorker.state(pid)
      # Batch should be dropped
      assert :queue.to_list(state.batches) == []

      GenServer.stop(pid)
    end

    test "queues new events during retry attempts", %{
      config: config,
      change_behavior: change_behavior
    } do
      {:ok, pid} = start_worker(config)

      change_behavior.(:error)

      # Send first batch
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))

      # Wait for first attempt
      assert_receive {:events_sent, ^first_batch}, 50

      # Send new events during retry period
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))

      # Switch to success before max retries
      change_behavior.(:ok)

      # Should eventually send both batches
      assert_receive {:events_sent, ^first_batch}, 150
      assert_receive {:events_sent, ^second_batch}, 50

      GenServer.stop(pid)
    end

    test "does not reset flush timer on subsequent pushes", %{config: config} do
      {:ok, pid} =
        start_worker(Keyword.merge(config, timeout: 100, batch_size: 1000))

      EventsWorker.push(%{id: 1}, pid)
      :timer.sleep(60)
      EventsWorker.push(%{id: 2}, pid)
      :timer.sleep(60)
      EventsWorker.push(%{id: 3}, pid)

      assert_receive {:events_sent, [%{id: 1}, %{id: 2}]}
      assert_receive {:events_sent, [%{id: 3}]}, 100

      GenServer.stop(pid)
    end

    test "works with pushes after a flush", %{config: config} do
      {:ok, pid} =
        start_worker(Keyword.merge(config, timeout: 50, batch_size: 1000))

      EventsWorker.push(%{id: 1}, pid)
      :timer.sleep(300)
      EventsWorker.push(%{id: 2}, pid)

      assert_receive {:events_sent, [%{id: 1}]}, 0
      # Make sure we don't get the second event before the timeout
      refute_receive {:events_sent, [%{id: 2}]}, 0
      assert_receive {:events_sent, [%{id: 2}]}, 100

      GenServer.stop(pid)
    end

    test "handles throttling and resumes after wait period", %{
      config: config,
      change_behavior: change_behavior
    } do
      {:ok, pid} = start_worker(config)

      # Start with throttle behavior
      change_behavior.(:throttle)

      # Send first batch
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1, pid))

      # Should get throttled
      assert_receive {:events_sent, ^first_batch}, 50

      # Send second batch while throttled
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1, pid))

      # Switch to success after throttle period
      change_behavior.(:ok)

      # Should send both batches after throttle period
      assert_receive {:events_sent, ^first_batch}, 350
      assert_receive {:events_sent, ^second_batch}, 50

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
