defmodule Honeybadger.Insights.LiveViewTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  @required_atoms [:phoenix, :live_view, :live_component, :operation]

  # Define mock module for testing
  defmodule Phoenix.LiveView do
  end

  describe "LiveView instrumentation" do
    test "extracts metadata from mount event" do
      event =
        send_and_receive(
          [:phoenix, :live_view, :mount, :stop],
          %{duration: System.convert_time_unit(15, :millisecond, :native)},
          %{
            uri: "/dashboard",
            socket_id: "phx-Fxyz123",
            socket: %{
              view: MyApp.DashboardLive,
              assigns: %{
                page_title: "Dashboard",
                user_id: 123
              }
            },
            params: %{"tab" => "overview"}
          }
        )

      assert event["url"] == "/dashboard"
      assert event["socket_id"] == "phx-Fxyz123"
      assert event["view"] == "MyApp.DashboardLive"
      assert event["params"] == %{"tab" => "overview"}
      assert event["assigns"]["page_title"] == "Dashboard"
      assert event["assigns"]["user_id"] == 123
    end

    test "handles missing socket data gracefully" do
      event =
        send_and_receive(
          [:phoenix, :live_view, :mount, :stop],
          %{duration: System.convert_time_unit(10, :millisecond, :native)},
          %{
            uri: "/dashboard",
            socket_id: "phx-Ghi012",
            params: %{"id" => "123"}
            # No socket data provided
          }
        )

      assert event["url"] == "/dashboard"
      assert event["socket_id"] == "phx-Ghi012"
      assert event["params"] == %{"id" => "123"}
      assert event["view"] == nil
      assert event["assigns"] == nil
    end
  end
end
