defmodule Honeybadger.Insights.BaseTest do
  use Honeybadger.Case, async: false

  defmodule TestEventFilter do
    def filter(data, _raw, _name) do
      Map.put(data, :was_filtered, true)
    end
  end

  defmodule TestInsights do
    use Honeybadger.Insights.Base

    @required_dependencies []
    @telemetry_events [
      "test.event.one",
      "test.event.two"
    ]

    # Minimal extraction to verify it's called
    def extract_metadata(meta, _name) do
      Map.put(meta, :was_processed, true)
    end

    # Override process_event to simply send the message to test process
    def process_event(event_data) do
      send(self(), {:event_processed, event_data})
    end

    # We need to make sure to detach so each run is clean
    def detach() do
      Enum.each(@telemetry_events, fn e -> :telemetry.detach(e) end)
    end
  end

  test "attaches to and processes telemetry events" do
    with_config([event_filter: TestEventFilter], fn ->
      TestInsights.attach()

      # Send test events
      :telemetry.execute([:test, :event, :one], %{value: 1}, %{data: "test"})
      :telemetry.execute([:test, :event, :two], %{value: 2}, %{data: "other"})

      # Just verify we got both events and they were processed
      assert_received {:event_processed, event1}, 50
      assert event1.event_type == "test.event.one"
      assert event1.was_processed
      assert event1.was_filtered

      assert_received {:event_processed, event2}
      assert event2.event_type == "test.event.two"
      assert event2.was_processed
      assert event1.was_filtered

      TestInsights.detach()
    end)
  end

  test "process measurement data" do
    TestInsights.attach()

    measurements = %{
      duration: 1_000_000,
      total_time: 2_000_000,
      decode_time: 3_000_000,
      query_time: 4_000_000,
      queue_time: 5_000_000,
      idle_time: 6_000_000,
      monotonic_time: 10_000_000
    }

    :telemetry.execute([:test, :event, :two], measurements, %{data: "other"})

    assert_received {:event_processed, event}, 50

    # Hardcoded expected values after converting native to milliseconds
    # Assuming 1000 native time units equal 1 millisecond:
    assert event.duration == 1
    assert event.total_time == 2
    assert event.decode_time == 3
    assert event.query_time == 4
    assert event.queue_time == 5
    assert event.idle_time == 6

    refute Map.has_key?(event, :monotonic_time)

    TestInsights.detach()
  end

  test "sanitizes nested data" do
    TestInsights.attach()

    :telemetry.execute([:test, :event, :one], %{value: 1}, %{
      data: "test",
      nested: %{
        __changed__: "changed",
        more: %{
          flash: "bang"
        }
      }
    })

    assert_received {:event_processed, event}, 50
    refute get_in(event, [:nested, :more, :flash])
    refute get_in(event, [:nested, :__changed__])

    TestInsights.detach()
  end

  test "removes params" do
    with_config(
      [filter_disable_params: true, filter_disable_assigns: true, filter_disable_session: true],
      fn ->
        TestInsights.attach()

        :telemetry.execute([:test, :event, :two], %{value: 1}, %{
          data: "test",
          session: %{user_id: 123},
          assigns: %{other: "value"},
          params: %{password: "secret"}
        })

        assert_received {:event_processed, event}, 50
        refute event[:params]
        refute event[:assigns]
        refute event[:assigns]

        TestInsights.detach()
      end
    )
  end

  test "limits telemetry events" do
    with_config(
      [insights_config: %{test_insights: %{telemetry_events: ["test.event.one"]}}],
      fn ->
        TestInsights.attach()

        :telemetry.execute([:test, :event, :one], %{value: 1}, %{data: "test"})
        :telemetry.execute([:test, :event, :two], %{value: 2}, %{data: "other"})

        assert_received {:event_processed, _event1}, 50
        refute_received {:event_processed, _event2}

        TestInsights.detach()
      end
    )
  end
end
