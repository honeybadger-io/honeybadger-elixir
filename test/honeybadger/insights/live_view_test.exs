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

  describe "mount start handler" do
    test "sets socket_id in event context from socket" do
      :telemetry.execute(
        [:phoenix, :live_view, :mount, :start],
        %{},
        %{
          socket: %{
            id: "phx-Fmount123",
            view: MyApp.DashboardLive,
            assigns: %{}
          }
        }
      )

      assert Honeybadger.EventContext.get(:socket_id) == "phx-Fmount123"
    end

    test "sets socket_id in event context from socket_id key" do
      :telemetry.execute(
        [:phoenix, :live_view, :mount, :start],
        %{},
        %{
          socket_id: "phx-Gtop456"
        }
      )

      assert Honeybadger.EventContext.get(:socket_id) == "phx-Gtop456"
    end

    test "socket_id propagates to subsequent events" do
      :telemetry.execute(
        [:phoenix, :live_view, :mount, :start],
        %{},
        %{
          socket: %{
            id: "phx-Hprop789",
            view: MyApp.DashboardLive,
            assigns: %{}
          }
        }
      )

      event =
        send_and_receive(
          [:phoenix, :live_view, :handle_event, :stop],
          %{duration: System.convert_time_unit(5, :microsecond, :native)},
          %{
            uri: "/dashboard",
            socket: %{
              id: "phx-Hprop789",
              view: MyApp.DashboardLive,
              assigns: %{}
            },
            event: "click"
          }
        )

      assert event["socket_id"] == "phx-Hprop789"
    end

    test "does not overwrite existing socket_id in event context" do
      Honeybadger.EventContext.merge(%{socket_id: "existing-id"})

      :telemetry.execute(
        [:phoenix, :live_view, :mount, :start],
        %{},
        %{
          socket: %{
            id: "phx-Inew999",
            view: MyApp.DashboardLive,
            assigns: %{}
          }
        }
      )

      assert Honeybadger.EventContext.get(:socket_id) == "existing-id"
    end
  end
end
