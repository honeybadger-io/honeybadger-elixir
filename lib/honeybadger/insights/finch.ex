defmodule Honeybadger.Insights.Finch do
  @moduledoc """
  Captures telemetry events from HTTP requests made using Finch.

  ## Default Configuration

  By default, this module listens for the standard Finch request telemetry event:

      "finch.request.stop"

  ## Custom Configuration

  You can customize the telemetry events to listen for by updating the insights_config:

      config :honeybadger, insights_config: %{
        finch: %{
          telemetry_events: ["finch.request.stop", "finch.request.exception"],

          # Include full URLs in telemetry events (default: false - only hostname is included)
          full_url: false
        }
      }

  By default, only the hostname from URLs is captured for security and privacy reasons.
  If you need to capture the full URL including paths (but not query parameters),
  you can enable the `full_url` option.
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Finch]

  @telemetry_events [
    [:finch, :request, :stop]
  ]

  def extract_metadata(meta, _) do
    metadata = %{
      name: meta.name,
      method: meta.request.method,
      host: meta.request.host
    }

    metadata =
      if get_insights_config(:full_url, false) do
        Map.put(metadata, :url, reconstruct_url(meta.request))
      else
        metadata
      end

    case meta.result do
      {:ok, response} when is_struct(response, Finch.Response) ->
        Map.merge(metadata, %{status: response.status})

      {:ok, _acc} ->
        # For streaming requests
        Map.put(metadata, :streaming, true)

      {:error, error} ->
        Map.put(metadata, :error, Exception.message(error))
    end
  end

  defp reconstruct_url(request) do
    # Exclude query parameters for security reasons
    port_string = get_port_string(request.scheme, request.port)

    "#{request.scheme}://#{request.host}#{port_string}#{request.path}"
  end

  defp get_port_string(scheme, port) do
    cond do
      is_nil(port) -> ""
      (scheme == :http and port == 80) or (scheme == :https and port == 443) -> ""
      true -> ":#{port}"
    end
  end
end
