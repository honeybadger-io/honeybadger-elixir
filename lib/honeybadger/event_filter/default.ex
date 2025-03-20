defmodule Honeybadger.EventFilter.Default do
  @behaviour Honeybadger.EventFilter

  alias Honeybadger.Utils

  def filter_telemetry_event(data, _raw, _event) do
    data
    |> disable(:filter_disable_url, :url)
    |> disable(:filter_disable_session, :session)
    |> disable(:filter_disable_assigns, :assigns)
    |> disable(:filter_disable_params, :params)
    |> Utils.sanitize(remove_filtered: true)
  end

  defp disable(meta, config_key, map_key) do
    if Honeybadger.get_env(config_key) do
      Map.drop(meta, [map_key])
    else
      meta
    end
  end
end
