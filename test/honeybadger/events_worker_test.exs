defmodule Honeybadger.EventsWorkerTest do
  use ExUnit.Case, async: true
  require Logger

  alias Honeybadger.EventsWorker

  defmodule TestBackend do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
      {:ok, %{behavior: :ok}}
    end

    def set_behavior(behavior) do
      GenServer.call(__MODULE__, {:set_behavior, behavior})
    end

    def send_events(events) do
      send(Process.whereis(:test_process), {:events_sent, events})
      GenServer.call(__MODULE__, :get_response)
    end

    def handle_call({:set_behavior, behavior}, _from, state) do
      {:reply, :ok, %{state | behavior: behavior}}
    end

    def handle_call(:get_response, _from, %{behavior: :ok} = state) do
      {:reply, :ok, state}
    end

    def handle_call(:get_response, _from, %{behavior: :throttle} = state) do
      {:reply, {:error, :throttled}, state}
    end

    def handle_call(:get_response, _from, %{behavior: :error} = state) do
      {:reply, {:error, "Other error"}, state}
    end
  end

  setup do
    Process.register(self(), :test_process)
    {:ok, _} = TestBackend.start_link()

    # Common test configuration
    config = [
      backend: TestBackend,
      batch_size: 3,
      timeout: 100
    ]

    {:ok, config: config}
  end

  describe "batch size triggering" do
    test "sends events when batch size is reached", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)
      events = [%{id: 1}, %{id: 2}, %{id: 3}]
      Enum.each(events, &EventsWorker.push(&1))
      GenServer.stop(pid)

      assert_receive {:events_sent, ^events}, 50
    end

    test "queues events when under batch size", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)

      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1))
      refute_receive {:events_sent, _}, 50

      GenServer.stop(pid)
    end
  end

  describe "max_queue_size" do
    test "drops events from queue", %{config: config} do
      {:ok, pid} =
        EventsWorker.start_link(
          config ++ [backend: TestBackend, timeout: 5000, max_queue_size: 4]
        )

      TestBackend.set_behavior(:error)
      events = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}, %{id: 6}]
      Enum.each(events, &EventsWorker.push(&1))

      state = EventsWorker.state()

      assert state.dropped_events == 2
      assert state.queue == [%{id: 4}]
      assert state.batches == [%{attempts: 1, batch: [%{id: 1}, %{id: 2}, %{id: 3}]}]

      GenServer.stop(pid)
    end
  end

  describe "timer triggering" do
    test "flushes events when timer expires", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1))
      assert_receive {:events_sent, ^events}, config[:timeout] + 50
      GenServer.stop(pid)
    end

    test "resets timer when batch is sent", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)

      first_batch = [%{id: 1}, %{id: 2}, %{id: 3}]
      Enum.each(first_batch, &EventsWorker.push(&1))
      assert_receive {:events_sent, ^first_batch}, 50

      second_batch = [%{id: 4}, %{id: 5}]
      Enum.each(second_batch, &EventsWorker.push(&1))
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
          max_batch_retries: 2,
          throttle_wait: 300,
          max_queue_size: 6
        )

      {:ok, config: config}
    end

    test "retries and drops after max attempts", %{config: config} do
      config = Keyword.merge(config, max_batch_retries: 3)

      {:ok, pid} = EventsWorker.start_link(config)

      # Start with error behavior
      TestBackend.set_behavior(:error)

      # Send enough events to trigger a batch
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1))

      # Wait for first attempt
      assert_receive {:events_sent, ^events}, 50

      # Should retry after timeout
      assert_receive {:events_sent, ^events}, 150

      # Should retry one more time and then drop
      assert_receive {:events_sent, ^events}, 250

      # Check final state
      state = EventsWorker.state()
      # Batch should be dropped
      assert state.batches == []

      GenServer.stop(pid)
    end

    test "queues new events during retry attempts", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)

      # Start with error behavior
      TestBackend.set_behavior(:error)

      # Send first batch
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1))

      # Wait for first attempt
      assert_receive {:events_sent, ^first_batch}, 50

      # Send new events during retry period
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1))

      # Switch to success before max retries
      TestBackend.set_behavior(:ok)

      # Should eventually send both batches
      assert_receive {:events_sent, ^first_batch}, 150
      assert_receive {:events_sent, ^second_batch}, 50

      GenServer.stop(pid)
    end

    test "handles throttling and resumes after wait period", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)

      # Start with throttle behavior
      TestBackend.set_behavior(:throttle)

      # Send first batch
      first_batch = [%{id: 1}, %{id: 2}]
      Enum.each(first_batch, &EventsWorker.push(&1))

      # Should get throttled
      assert_receive {:events_sent, ^first_batch}, 50

      # Send second batch while throttled
      second_batch = [%{id: 3}, %{id: 4}]
      Enum.each(second_batch, &EventsWorker.push(&1))

      # Switch to success after throttle period
      TestBackend.set_behavior(:ok)

      # Should send both batches after throttle period
      assert_receive {:events_sent, ^first_batch}, 350
      assert_receive {:events_sent, ^second_batch}, 50

      GenServer.stop(pid)
    end

    test "preserves batches while throttling", %{config: config} do
      {:ok, _pid} = EventsWorker.start_link(config)
      TestBackend.set_behavior(:throttle)
      first_batch = [%{id: 1}, %{id: 2}]
      rest = [%{id: 3}, %{id: 4}, %{id: 5}, %{id: 6}]
      Enum.each(first_batch ++ rest, &EventsWorker.push(&1))
      assert_receive {:events_sent, ^first_batch}, 50
      state = EventsWorker.state()
      assert length(state.batches) == 3
    end
  end

  describe "termination" do
    test "sends remaining events on termination", %{config: config} do
      {:ok, pid} = EventsWorker.start_link(config)
      events = [%{id: 1}, %{id: 2}]
      Enum.each(events, &EventsWorker.push(&1))
      assert_receive {:events_sent, ^events}, 500

      GenServer.stop(pid)
    end
  end
end
