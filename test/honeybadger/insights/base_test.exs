defmodule Honeybadger.Insights.BaseTest do
  use Honeybadger.Case, async: false

  defmodule TestEventFilter do
    def filter(data, _name) do
      # Simply pass through the data
      data
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
  end

  setup do
    # Attach our test insights
    TestInsights.attach()

    :ok
  end

  test "attaches to and processes telemetry events" do
    with_config([event_filter: TestEventFilter], fn ->
      # Send test events
      :telemetry.execute([:test, :event, :one], %{value: 1}, %{data: "test"})
      :telemetry.execute([:test, :event, :two], %{value: 2}, %{data: "other"})

      # Just verify we got both events and they were processed
      assert_received {:event_processed, event1}, 50
      assert event1.event_type == "test.event.one"
      assert event1.was_processed

      assert_received {:event_processed, event2}
      assert event2.event_type == "test.event.two"
      assert event2.was_processed
    end)
  end

  test "sanitizes nested data" do
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
  end

  test "removes params" do
    with_config(
      [filter_disable_params: true, filter_disable_assigns: true, filter_disable_session: true],
      fn ->
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
      end
    )
  end
end
