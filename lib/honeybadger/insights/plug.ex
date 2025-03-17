defmodule Honeybadger.Insights.Plug do
  @moduledoc """
  Captures telemetry events from HTTP requests processed by Plug and Phoenix.

  ## Default Configuration

  By default, this module listens for the standard Phoenix endpoint telemetry event:

      "phoenix.endpoint.stop"

  This is compatible with the default Phoenix configuration that adds telemetry
  via `Plug.Telemetry`:

      plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  ## Custom Configuration

  You can customize the telemetry events to listen for by updating the insights_config:

      config :honeybadger, insights_config: %{
        plug: %{
          telemetry_events: [[:my, :prefix, :stop]]
        }
      }
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Plug]

  @telemetry_events [
    [:phoenix, :endpoint, :stop]
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
