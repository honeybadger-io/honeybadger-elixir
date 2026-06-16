defmodule Honeybadger.Insights.LiveView do
  @moduledoc """
  Captures telemetry events from Phoenix LiveView.

  ## Default Configuration

  By default, this module listens for the following LiveView telemetry events:

     "phoenix.live_view.mount.stop"
     "phoenix.live_component.handle_event.stop"
     "phoenix.live_view.update.stop"

  ## Custom Configuration

  You can customize the telemetry events to listen for by updating the insights_config:

     config :honeybadger, insights_config: %{
       live_view: %{
         telemetry_events: [
           [:phoenix, :live_view, :mount, :stop],
           [:phoenix, :live_component, :handle_event, :stop],
           [:phoenix, :live_component, :update, :stop]
           [:phoenix, :live_view, :handle_event, :stop],
           [:phoenix, :live_view, :handle_params, :stop],
           [:phoenix, :live_view, :update, :stop]
         ]
       }
     }
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Phoenix.LiveView]

  @telemetry_events [
    # LiveView events
    [:phoenix, :live_view, :mount, :stop],
    [:phoenix, :live_view, :handle_params, :stop],
    [:phoenix, :live_view, :handle_event, :stop],

    # LiveComponent events
    [:phoenix, :live_component, :handle_event, :stop],
    [:phoenix, :live_component, :update, :stop]
  ]

  def get_telemetry_events() do
    events = get_insights_config(:telemetry_events, @telemetry_events)

    [[:phoenix, :live_view, :mount, :start]] ++ events
  end

  def handle_telemetry(
        [:phoenix, :live_view, :mount, :start] = event,
        measurements,
        metadata,
        opts
      ) do
    Honeybadger.EventContext.inherit()

    Honeybadger.EventContext.put_new(:request_id, fn ->
      Honeybadger.Utils.rand_id()
    end)

    Honeybadger.EventContext.put_new(:socket_id, fn ->
      extract_socket_id(metadata)
    end)

    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end
  end

  def extract_metadata(meta, _event) do
    %{
      url: Map.get(meta, :uri),
      socket_id: extract_socket_id(meta),
      view: extract_view(meta),
      component: extract_component(meta),
      assigns: extract_assigns(meta),
      params: Map.get(meta, :params),
      event: Map.get(meta, :event)
    }
  end

  defp extract_component(%{component: component}), do: get_module_name(component)
  defp extract_component(%{socket: %{live_component: component}}), do: get_module_name(component)
  defp extract_component(_), do: nil

  defp extract_socket_id(%{socket_id: id}), do: id
  defp extract_socket_id(%{socket: %{id: id}}), do: id
  defp extract_socket_id(_), do: nil

  defp extract_view(%{socket: %{view: view}}), do: get_module_name(view)
  defp extract_view(_), do: nil

  defp extract_assigns(%{socket: %{assigns: assigns}}), do: assigns
  defp extract_assigns(_), do: nil
end
