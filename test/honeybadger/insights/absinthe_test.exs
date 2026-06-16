defmodule Honeybadger.Insights.AbsintheTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  # Define mock module for testing
  defmodule Absinthe do
  end

  describe "Absinthe instrumentation" do
    test "extracts metadata from operation stop event" do
      operation = %{
        name: "GetUser",
        type: :query,
        current: true,
        selections: [
          %{name: "user"},
          %{name: "profile"}
        ]
      }

      blueprint = %{
        schema: MyApp.Schema,
        operations: [operation],
        result: %{
          errors: nil
        }
      }

      event =
        send_and_receive(
          [:absinthe, :execute, :operation, :stop],
          %{duration: System.convert_time_unit(25, :microsecond, :native)},
          %{blueprint: blueprint}
        )

      assert event["event_type"] == "absinthe.execute.operation.stop"
      assert event["operation_name"] == "GetUser"
      assert event["operation_type"] == "query"
      assert event["selections"] == ["user", "profile"]
      assert event["schema"] == "Elixir.MyApp.Schema"
      assert event["errors"] == nil
      assert event["duration"] == 25
    end

    test "extracts metadata from operation exception event" do
      operation = %{
        name: "GetUser",
        type: :query,
        current: true,
        selections: [
          %{name: "user"},
          %{name: "profile"}
        ]
      }

      blueprint = %{
        schema: MyApp.Schema,
        operations: [operation],
        result: %{
          errors: [%{message: "Field 'user' not found"}]
        }
      }

      event =
        send_and_receive(
          [:absinthe, :execute, :operation, :exception],
          %{duration: System.convert_time_unit(15, :microsecond, :native)},
          %{blueprint: blueprint}
        )

      assert event["event_type"] == "absinthe.execute.operation.exception"
      assert event["operation_name"] == "GetUser"
      assert event["operation_type"] == "query"
      assert event["selections"] == ["user", "profile"]
      assert event["schema"] == "Elixir.MyApp.Schema"
      assert event["errors"] == [%{"message" => "Field 'user' not found"}]
      assert event["duration"] == 15
    end

    test "extracts metadata from resolve field stop event" do
      restart_with_config(
        insights_config: %{absinthe: %{telemetry_events: [[:absinthe, :resolve, :field, :stop]]}}
      )

      resolution = %{
        definition: %{
          name: "name"
        },
        parent_type: %{
          name: "User"
        },
        state: :resolved
      }

      event =
        send_and_receive(
          [:absinthe, :resolve, :field, :stop],
          %{duration: System.convert_time_unit(5, :microsecond, :native)},
          %{resolution: resolution}
        )

      assert event["event_type"] == "absinthe.resolve.field.stop"
      assert event["field_name"] == "name"
      assert event["parent_type"] == "User"
      assert event["state"] == "resolved"
      assert event["duration"] == 5
    end

    test "handles missing blueprint data gracefully" do
      event =
        send_and_receive(
          [:absinthe, :execute, :operation, :stop],
          %{duration: System.convert_time_unit(10, :microsecond, :native)},
          # No blueprint data
          %{}
        )

      assert event["event_type"] == "absinthe.execute.operation.stop"
      assert event["operation_name"] == nil
      assert event["operation_type"] == nil
      assert event["selections"] == []
      assert event["schema"] == nil
      assert event["errors"] == nil
      assert event["duration"] == 10
    end

    test "handles operations without selections" do
      operation = %{
        name: "GetUser",
        type: :query,
        current: true
        # No selections key
      }

      blueprint = %{
        schema: MyApp.Schema,
        operations: [operation]
      }

      event =
        send_and_receive(
          [:absinthe, :execute, :operation, :stop],
          %{duration: System.convert_time_unit(8, :microsecond, :native)},
          %{blueprint: blueprint}
        )

      assert event["event_type"] == "absinthe.execute.operation.stop"
      assert event["operation_name"] == "GetUser"
      assert event["operation_type"] == "query"
      # Should handle missing selections
      assert event["selections"] == []
      assert event["schema"] == "Elixir.MyApp.Schema"
      assert event["duration"] == 8
    end
  end
end
