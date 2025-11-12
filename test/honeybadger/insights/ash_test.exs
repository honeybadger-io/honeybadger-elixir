defmodule Ash.Domain.Info do
  def short_name(domain) do
    domain
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end
end

defmodule Honeybadger.Insights.AshTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  # Define mock modules for testing
  defmodule Ash do
  end

  defmodule Test.Accounts do
  end

  defmodule Test.Posts do
  end

  setup do
    restart_with_config(ash_domains: [Test.Accounts, Test.Posts])
  end

  describe "Ash instrumentation" do
    test "extracts metadata from create action event" do
      event =
        send_and_receive(
          [:ash, :accounts, :create, :stop],
          %{duration: System.convert_time_unit(15, :microsecond, :native)},
          %{
            resource_short_name: :user,
            action: :register
          }
        )

      assert event["resource_short_name"] == "user"
      assert event["action"] == "register"
      assert event["duration"] == 15
    end

    test "extracts metadata from read action event" do
      event =
        send_and_receive(
          [:ash, :posts, :read, :stop],
          %{duration: System.convert_time_unit(8, :microsecond, :native)},
          %{
            resource_short_name: :post,
            action: :list
          }
        )

      assert event["resource_short_name"] == "post"
      assert event["action"] == "list"
      assert event["duration"] == 8
    end

    test "extracts metadata from update action event" do
      event =
        send_and_receive(
          [:ash, :accounts, :update, :stop],
          %{duration: System.convert_time_unit(12, :microsecond, :native)},
          %{
            resource_short_name: :user,
            action: :change_password
          }
        )

      assert event["resource_short_name"] == "user"
      assert event["action"] == "change_password"
      assert event["duration"] == 12
    end

    test "extracts metadata from destroy action event" do
      event =
        send_and_receive(
          [:ash, :posts, :destroy, :stop],
          %{duration: System.convert_time_unit(10, :microsecond, :native)},
          %{
            resource_short_name: :post,
            action: :delete
          }
        )

      assert event["resource_short_name"] == "post"
      assert event["action"] == "delete"
      assert event["duration"] == 10
    end

    test "extracts metadata from generic action event" do
      event =
        send_and_receive(
          [:ash, :accounts, :action, :stop],
          %{duration: System.convert_time_unit(20, :microsecond, :native)},
          %{
            resource_short_name: :user,
            action: :custom_action
          }
        )

      assert event["resource_short_name"] == "user"
      assert event["action"] == "custom_action"
      assert event["duration"] == 20
    end

    test "handles missing metadata gracefully" do
      event =
        send_and_receive(
          [:ash, :accounts, :create, :stop],
          %{duration: System.convert_time_unit(5, :microsecond, :native)},
          %{}
        )

      assert event["resource_short_name"] == nil
      assert event["action"] == nil
      assert event["duration"] == 5
    end
  end

  describe "get_telemetry_events/0" do
    test "returns events for configured domains" do
      events = Honeybadger.Insights.Ash.get_telemetry_events()

      # Should include events for both test domains
      assert [:ash, :accounts, :create, :stop] in events
      assert [:ash, :accounts, :read, :stop] in events
      assert [:ash, :accounts, :update, :stop] in events
      assert [:ash, :accounts, :destroy, :stop] in events
      assert [:ash, :accounts, :action, :stop] in events

      assert [:ash, :posts, :create, :stop] in events
      assert [:ash, :posts, :read, :stop] in events
      assert [:ash, :posts, :update, :stop] in events
      assert [:ash, :posts, :destroy, :stop] in events
      assert [:ash, :posts, :action, :stop] in events
    end

    test "merges custom events with domain events" do
      with_config(
        [
          ash_domains: [Test.Accounts],
          insights_config: %{
            ash: %{
              telemetry_events: [
                [:ash, :validation, :stop],
                [:ash, :calculation, :stop]
              ]
            }
          }
        ],
        fn ->
          events = Honeybadger.Insights.Ash.get_telemetry_events()

          # Should include domain events
          assert [:ash, :accounts, :create, :stop] in events
          assert [:ash, :accounts, :read, :stop] in events

          # Should also include custom events
          assert [:ash, :validation, :stop] in events
          assert [:ash, :calculation, :stop] in events
        end
      )
    end

    test "handles missing ash_domains configuration gracefully" do
      with_config([ash_domains: nil], fn ->
        # Should not raise an error and return only custom events if any
        events = Honeybadger.Insights.Ash.get_telemetry_events()
        assert is_list(events)
      end)
    end

    test "deduplicates events when custom events overlap with domain events" do
      with_config(
        [
          ash_domains: [Test.Accounts],
          insights_config: %{
            ash: %{
              telemetry_events: [
                [:ash, :accounts, :create, :stop],
                [:ash, :accounts, :create, :stop]
              ]
            }
          }
        ],
        fn ->
          events = Honeybadger.Insights.Ash.get_telemetry_events()

          # Should only have one instance of the create event
          create_events =
            Enum.filter(events, fn event ->
              event == [:ash, :accounts, :create, :stop]
            end)

          assert length(create_events) == 1
        end
      )
    end
  end
end
