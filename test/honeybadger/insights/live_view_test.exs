defmodule Honeybadger.Insights.LiveViewTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  # Define mock module for testing
  defmodule Phoenix.LiveView do
  end

  describe "LiveView instrumentation" do
    test "extracts metadata from mount event" do
      restart_with_config(filter_disable_assigns: false)

      event =
        send_and_receive(
          [:phoenix, :live_view, :mount, :stop],
          %{duration: System.convert_time_unit(15, :microsecond, :native)},
          %{
            uri: "/dashboard",
            socket: %{
              id: "phx-Fxyz123",
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
          %{duration: System.convert_time_unit(10, :microsecond, :native)},
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
