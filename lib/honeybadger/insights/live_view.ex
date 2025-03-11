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
           "phoenix.live_view.mount.stop",
           "phoenix.live_view.update.stop",
           "phoenix.live_view.handle_event.stop"
         ]
       }
     }
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Phoenix.LiveView]

  @telemetry_events [
    "phoenix.live_component.handle_event.stop",
    "phoenix.live_view.mount.stop",
    "phoenix.live_view.update.stop"
  ]

  def extract_metadata(meta, _) do
    %{
      url: Map.get(meta, :uri),
      socket_id: Map.get(meta, :socket_id),
      view: extract_view(meta),
      assigns: extract_assigns(meta),
      params: Map.get(meta, :params),
      event: Map.get(meta, :event)
    }
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
