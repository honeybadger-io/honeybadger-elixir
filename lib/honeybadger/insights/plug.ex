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

  def get_telemetry_events do
    events = get_insights_config(:telemetry_events, @telemetry_events)

    Enum.reduce(events, events, fn init, acc ->
      if List.last(init) == :stop do
        acc ++ [Enum.drop(init, -1) ++ [:start]]
      else
        acc
      end
    end)
  end

  def handle_telemetry([_, _, :start] = event, measurements, metadata, opts) do
    metadata.conn
    |> get_request_id()
    |> Honeybadger.set_request_id()

    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end
  end

  def extract_metadata(meta, _) do
    conn = meta.conn

    %{
      params: conn.params,
      method: conn.method,
      request_path: conn.request_path,
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
