defmodule Honeybadger.Breadcrumbs.TelemetryTest do
  use Honeybadger.Case, async: true

  alias Honeybadger.Breadcrumbs.{Telemetry, Collector}

  defmodule Test.MockEctoConfig do
    def config() do
      [telemetry_prefix: [:a, :b]]
    end
  end

  test "inserts ecto telemetry events" do
    with_config([ecto_repos: [Test.MockEctoConfig]], fn ->
      assert Telemetry.telemetry_events() == [
               [:a, :b, :query],
               [:phoenix, :router_dispatch, :start]
             ]
    end)
  end

  test "works without ecto" do
    assert Telemetry.telemetry_events() == [[:phoenix, :router_dispatch, :start]]
  end

  test "produces merged sql breadcrumb" do
    with_config([breadcrumbs_enabled: true], fn ->
      query = "SELECT * from table"

      Telemetry.handle_telemetry(
        [],
        %{decode_time: 66_000_000},
        %{query: query, source: "here"},
        nil
      )

      bc = latest_breadcrumb()
      assert bc.message == "Ecto SQL Query (here)"
      assert bc.metadata[:decode_time] == "66.0ms"
    end)
  end

  test "produces sql breadcrumb without telemetry measurements" do
    with_config([breadcrumbs_enabled: true], fn ->
      query = "SELECT * from table"

      Telemetry.handle_telemetry(
        [],
        4000,
        %{query: query, source: "table", query_time: 4_000_000},
        nil
      )

      bc = latest_breadcrumb()
      assert bc.message == "Ecto SQL Query (table)"
      assert bc.metadata[:query_time] == "4.0ms"
    end)
  end

  test "produces phoenix router breadcrumb" do
    with_config([breadcrumbs_enabled: true], fn ->
      Telemetry.handle_telemetry(
        [:phoenix, :router_dispatch, :start],
        4000,
        %{plug: "Test.Controller", pipe_through: [:a, :b]},
        nil
      )

      bc = latest_breadcrumb()
      assert bc.message == "Phoenix Router Dispatch"
      assert bc.metadata[:plug] == "Test.Controller"
      assert bc.metadata[:pipe_through] == "[:a, :b]"
    end)
  end

  defp latest_breadcrumb() do
    hd(Collector.breadcrumbs().buffer)
  end
end
