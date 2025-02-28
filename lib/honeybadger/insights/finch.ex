defmodule Honeybadger.Insights.Finch do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Finch]

  @telemetry_events [
    "finch.request.stop"
  ]

  def extract_metadata(meta, _) do
    metadata = %{
      name: meta.name,
      method: meta.request.method,
      url: reconstruct_url(meta.request)
    }

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
