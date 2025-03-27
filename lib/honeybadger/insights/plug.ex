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
    |> then(fn
      nil -> :ok
      request_id -> Honeybadger.put_request_id(request_id)
    end)

    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end
  end

  def extract_metadata(meta, _event) do
    conn = meta.conn

    %{}
    |> add_basic_conn_info(conn)
    |> add_phoenix_live_view_metadata(conn)
    |> add_phoenix_controller_metadata(conn)
    |> add_common_phoenix_metadata(conn)
  end

  defp add_basic_conn_info(metadata, conn) do
    Map.merge(metadata, %{
      params: conn.params,
      method: conn.method,
      request_path: conn.request_path,
      status: conn.status
    })
  end

  defp add_phoenix_live_view_metadata(metadata, conn) do
    case conn.private[:phoenix_live_view] do
      nil ->
        metadata

      {module, opts, _extra} ->
        metadata
        |> Map.put(:route_type, :live)
        |> Map.put(:live_view, module)
        |> maybe_put(:live_action, get_in(opts, [:action]))
    end
  end

  defp add_phoenix_controller_metadata(metadata, conn) do
    case conn.private[:phoenix_controller] do
      nil ->
        metadata

      controller ->
        metadata
        |> Map.put(:route_type, :controller)
        |> Map.put(:controller, controller)
        |> maybe_put(:action, conn.private[:phoenix_action])
    end
  end

  defp add_common_phoenix_metadata(metadata, conn) do
    # Common keys regardless of route type
    common_keys = [
      {:phoenix_format, :format},
      {:phoenix_view, :view},
      {:phoenix_template, :template}
    ]

    # Set a default route_type if none has been set yet
    metadata_with_type =
      if Map.has_key?(metadata, :route_type),
        do: metadata,
        else: Map.put(metadata, :route_type, :unknown)

    # Add all available common keys
    Enum.reduce(common_keys, metadata_with_type, fn
      {:phoenix_view, key}, acc ->
        case conn.private[:phoenix_view] do
          %{_: view} ->
            maybe_put(acc, key, view)

          view when is_binary(view) ->
            maybe_put(acc, key, view)

          _ ->
            acc
        end

      {:phoenix_template, key}, acc ->
        case conn.private[:phoenix_template] do
          %{_: template} ->
            maybe_put(acc, key, template)

          template_map when is_map(template_map) ->
            format = conn.private[:phoenix_format]
            template = Map.get(template_map, format)
            if template, do: Map.put(acc, key, template), else: acc

          template when is_binary(template) ->
            maybe_put(acc, key, template)

          _ ->
            acc
        end

      {private_key, map_key}, acc ->
        maybe_put(acc, map_key, conn.private[private_key])
    end)
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
