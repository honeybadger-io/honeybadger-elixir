defmodule Honeybadger.Insights.Phoenix do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Phoenix.Endpoint]

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
      status: conn.status,
      session_data: Plug.Conn.get_session(conn)
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
