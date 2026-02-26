defmodule Honeybadger.Insights.AshTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  alias Honeybadger.Insights.Ash, as: AshTracer

  # Clean up the span stack between tests
  setup do
    Process.delete(:ash_honeybadger_spans)
    :ok
  end

  describe "start_span/2 and stop_span/0" do
    test "emits an event when a span completes" do
      AshTracer.start_span(:action, "User.create")
      AshTracer.stop_span()

      assert_receive {:api_request, event}
      assert event["event_type"] == "ash.action.stop"
      assert event["name"] == "User.create"
      assert is_binary(event["span_id"])
      assert is_integer(event["duration_microseconds"])
      assert event["duration_microseconds"] >= 0
      assert is_integer(event["timestamp"])
      assert event["parent_span_id"] == nil
    end

    test "stop_span with no active span is a no-op" do
      AshTracer.stop_span()
      refute_receive {:api_request, _}, 100
    end
  end

  describe "nested spans" do
    test "links child spans to parent via parent_span_id" do
      AshTracer.start_span(:action, "User.create")
      parent_context = AshTracer.get_span_context()
      parent_span_id = parent_context.honeybadger_span.id

      AshTracer.start_span(:custom, "changeset.validate")
      AshTracer.stop_span()

      assert_receive {:api_request, child_event}
      assert child_event["event_type"] == "ash.custom.stop"
      assert child_event["name"] == "changeset.validate"
      assert child_event["parent_span_id"] == parent_span_id

      AshTracer.stop_span()

      assert_receive {:api_request, parent_event}
      assert parent_event["event_type"] == "ash.action.stop"
      assert parent_event["name"] == "User.create"
      assert parent_event["parent_span_id"] == nil
    end
  end

  describe "set_metadata/2" do
    test "merges metadata into the current span" do
      AshTracer.start_span(:action, "User.create")
      AshTracer.set_metadata(:action, %{resource: "User", action: "create"})
      AshTracer.stop_span()

      assert_receive {:api_request, event}
      assert event["metadata"]["resource"] == "User"
      assert event["metadata"]["action"] == "create"
    end

    test "merges multiple metadata calls" do
      AshTracer.start_span(:action, "User.update")
      AshTracer.set_metadata(:action, %{resource: "User"})
      AshTracer.set_metadata(:action, %{action: "update", actor: "admin"})
      AshTracer.stop_span()

      assert_receive {:api_request, event}
      assert event["metadata"]["resource"] == "User"
      assert event["metadata"]["action"] == "update"
      assert event["metadata"]["actor"] == "admin"
    end

    test "no-op when no active span" do
      assert AshTracer.set_metadata(:action, %{resource: "User"}) == :ok
    end

    test "handles nil metadata" do
      AshTracer.start_span(:action, "User.create")
      AshTracer.set_metadata(:action, nil)
      AshTracer.stop_span()

      assert_receive {:api_request, event}
      assert event["metadata"] == %{}
    end
  end

  describe "set_error/2" do
    test "includes error info in the emitted event" do
      error = %RuntimeError{message: "something went wrong"}

      AshTracer.start_span(:action, "User.create")
      AshTracer.set_error(error)
      AshTracer.stop_span()

      assert_receive {:api_request, event}
      assert event["event_type"] == "ash.action.stop"
      assert event["error"]["class"] == "RuntimeError"
      assert event["error"]["message"] == "something went wrong"
    end

    test "creates an ephemeral span when no span is active" do
      error = %ArgumentError{message: "bad argument"}

      AshTracer.set_error(error)

      assert_receive {:api_request, event}
      assert event["event_type"] == "ash.custom.stop"
      assert event["name"] == "error"
      assert event["error"]["class"] == "ArgumentError"
      assert event["error"]["message"] == "bad argument"
    end

    test "cleans up span stack after ephemeral span" do
      error = %RuntimeError{message: "oops"}
      AshTracer.set_error(error)

      assert_receive {:api_request, _event}

      # Span stack should be empty
      assert AshTracer.get_span_context() == %{honeybadger_span: nil}
    end
  end

  describe "get_span_context/0 and set_span_context/1" do
    test "round-trips span context" do
      AshTracer.start_span(:action, "User.create")
      context = AshTracer.get_span_context()

      assert %{honeybadger_span: span} = context
      assert span.name == "User.create"
      assert span.type == :action

      # Simulate passing to another process
      Process.delete(:ash_honeybadger_spans)
      assert AshTracer.get_span_context() == %{honeybadger_span: nil}

      AshTracer.set_span_context(context)
      restored = AshTracer.get_span_context()
      assert restored.honeybadger_span.id == span.id
      assert restored.honeybadger_span.name == "User.create"

      # Clean up
      AshTracer.stop_span()
      assert_receive {:api_request, _event}
    end

    test "returns nil span when no span is active" do
      assert AshTracer.get_span_context() == %{honeybadger_span: nil}
    end

    test "set_span_context with nil span is a no-op" do
      assert AshTracer.set_span_context(%{honeybadger_span: nil}) == :ok
      assert AshTracer.get_span_context() == %{honeybadger_span: nil}
    end

    test "set_span_context with empty map is a no-op" do
      assert AshTracer.set_span_context(%{}) == :ok
      assert AshTracer.get_span_context() == %{honeybadger_span: nil}
    end
  end

  describe "trace_type?/1" do
    test "allows default types" do
      assert AshTracer.trace_type?(:custom)
      assert AshTracer.trace_type?(:action)
    end

    test "rejects non-default types" do
      refute AshTracer.trace_type?(:flow)
      refute AshTracer.trace_type?(:unknown)
    end

    test "unwraps {:custom, type} tuples" do
      assert AshTracer.trace_type?({:custom, :action})
      refute AshTracer.trace_type?({:custom, :flow})
    end

    test "respects custom trace_types config" do
      with_config(
        [insights_config: %{ash: %{trace_types: [:custom, :action, :flow]}}],
        fn ->
          assert AshTracer.trace_type?(:flow)
          assert AshTracer.trace_type?(:custom)
          assert AshTracer.trace_type?(:action)
          refute AshTracer.trace_type?(:unknown)
        end
      )
    end
  end
end
