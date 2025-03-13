defmodule Honeybadger.Insights.Tesla do
  @moduledoc """
  Captures telemetry events from Tesla HTTP requests.

  ## Configuration

  This module can be configured in the application config:

  ```elixir
  config :honeybadger, insights_config: %{
    tesla: %{
      # Include full URLs in telemetry events (default: false - only hostname is included)
      full_url: false,

      # Custom telemetry event patterns to listen for (optional)
      telemetry_events: ["tesla.request.stop", "tesla.request.exception"]
    }
  }
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Tesla]

  @telemetry_events [
    "tesla.request.stop",
    "tesla.request.exception"
  ]

  def extract_metadata(meta, _name) do
    env = Map.get(meta, :env, %{})

    base = %{
      method: env.method |> to_string() |> String.upcase(),
      host: extract_host(env.url),
      status_code: env.status
    }

    if get_insights_config(:full_url, false) do
      Map.put(base, :url, env.url)
    else
      base
    end
  end

  # Ignore telemetry events from Finch adapters, since we are already
  # instrumenting Finch requests in the Finch adapter module.
  def ignore?(meta) do
    adapter =
      meta
      |> Map.get(:env, %{})
      |> Map.get(:__client__, %{})
      |> Map.get(:adapter)

    case adapter do
      {Tesla.Adapter.Finch, _, _} -> true
      _ -> false
    end
  end

  defp extract_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> nil
    end
  end

  defp extract_host(_), do: nil
end
