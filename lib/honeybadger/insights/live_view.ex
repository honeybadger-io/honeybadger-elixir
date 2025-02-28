defmodule Honeybadger.Insights.LiveView do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Phoenix.LiveView]

  @telemetry_events [
    "phoenix.live_component.handle_event.stop",
    "phoenix.live_view.mount.stop",
    "phoenix.live_view.update.stop"
  ]

  def extract_metadata(meta, _) do
    %{
      meta: meta,
      duration: Map.get(meta, :duration, 0) / 1000,
      url: Map.get(meta, :uri),
      view: extract_view(meta),
      assigns: extract_assigns(meta),
      params: Map.get(meta, :params),
      live_view_event: Map.get(meta, :event)
    }
    |> Map.reject(fn {_, v} -> is_nil(v) end)
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
