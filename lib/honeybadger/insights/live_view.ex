defmodule Honeybadger.Insights.LiveView do
  @moduledoc """
  Captures telemetry events from Phoenix LiveView.

  ## Default Configuration

  By default, this module listens for the following LiveView telemetry events:

     "phoenix.live_component.handle_event.stop"
     "phoenix.live_view.mount.stop"
     "phoenix.live_view.update.stop"

  ## Custom Configuration

  You can customize the telemetry events to listen for by updating the insights_config:

     config :honeybadger, insights_config: %{
       live_view: %{
         telemetry_events: [
           [:phoenix, :live_component, :handle_event, :stop],
           [:phoenix, :live_view, :handle_event, :stop],
           [:phoenix, :live_view, :mount, :stop],
           [:phoenix, :live_view, :update, :stop]
         ]
       }
     }
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Phoenix.LiveView]

  @telemetry_events [
    [:phoenix, :live_component, :handle_event, :stop],
    [:phoenix, :live_view, :handle_event, :stop],
    [:phoenix, :live_view, :mount, :stop],
    [:phoenix, :live_view, :handle_params, :stop],
    [:phoenix, :live_view, :handle_event, :stop],

    # LiveComponent events (if you're using LiveView)
    [:phoenix, :live_component, :handle_event, :stop],
    [:phoenix, :live_component, :update, :stop]
  ]

  def get_telemetry_events() do
    events = get_insights_config(:telemetry_events, @telemetry_events)

    [[:phoenix, :live_view, :mount, :start]] ++ events
  end

  def extract_metadata(meta, _event) do
    %{
      url: Map.get(meta, :uri),
      socket_id: Map.get(meta, :socket_id),
      view: extract_view(meta),
      assigns: extract_assigns(meta),
      params: Map.get(meta, :params),
      event: Map.get(meta, :event)
    }
  end

  def handle_telemetry(
        [:phoenix, :live_view, :mount, :start] = event,
        measurements,
        metadata,
        opts
      ) do
    Honeybadger.RequestId.inherit_or_initialize()

    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end
  end

  def handle_telemetry([_, _, :handle_event, :stop] = event, measurements, metadata, opts) do
    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end

    Honeybadger.clear_request_id()
  end

  defp extract_view(%{socket: socket}) do
    socket.view |> get_module_name()
  rescue
    _ -> nil
  end

  defp extract_view(_), do: nil

  defp extract_assigns(%{socket: socket}) do
    socket.assigns
  rescue
    _ -> nil
  end

  defp extract_assigns(_), do: nil

  # Helper to get module name as string
  defp get_module_name(module) when is_atom(module), do: inspect(module)
  defp get_module_name(_), do: nil
end
