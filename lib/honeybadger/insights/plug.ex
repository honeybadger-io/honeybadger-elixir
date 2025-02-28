defmodule Honeybadger.Insights.Plug do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Plug]

  # This defaults to a default phoenix event prefix
  #
  #   plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  #
  # It can be customized by updating insights_config
  #
  #  config :honeybadger, insights_config: %{
  #    plug: %{telemetry_events: ["my.prefix.stop"]}}
  #
  @telemetry_events [
    "phoenix.endpoint.stop"
  ]

  def extract_metadata(meta, _) do
    conn = meta.conn

    %{
      params: conn.params,
      method: conn.method,
      request_path: conn.request_path,
      request_id: get_request_id(conn),
      status: conn.status
    }
  end

  defp get_request_id(conn) do
    case conn.assigns[:request_id] do
      nil ->
        conn
        |> Plug.Conn.get_resp_header("x-request-id")
        |> List.first()

      id ->
        id
    end
  end
end
