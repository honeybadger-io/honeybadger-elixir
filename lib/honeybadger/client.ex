defmodule Honeybadger.Client do
  alias Poison, as: JSON

  defstruct [:environment_name, :headers, :hostname, :origin]

  @metrics_endpoint "/v1/metrics"
  @notices_endpoint "/v1/notices"

  def new do
    origin = Application.get_env(:honeybadger, :origin)
    api_key = Application.get_env(:honeybadger, :api_key)
    env_name = Application.get_env(:honeybadger, :environment_name)
    hostname = Application.get_env(:honeybadger, :hostname)
    %__MODULE__{origin: origin, 
                headers: headers(api_key),
                environment_name: env_name,
                hostname: hostname}
  end

  def send_metric(%__MODULE__{} = client, metric, http_mod \\ HTTPoison) do
    body = JSON.encode!(%{
      environment: client.environment_name,
      hostname: client.hostname,
      metrics: metric
    })

    http_mod.post(
      client.origin <> @metrics_endpoint, body, client.headers
    )
  end

  def send_notice(%__MODULE__{} = client, metric, http_mod \\ HTTPoison) do
    body = JSON.encode!(metric)

    http_mod.post(
      client.origin <> @notices_endpoint, body, client.headers
    )
  end

  defp headers(api_key) do
    [{"Accept", "application/json"},
     {"Content-Type", "application/json"},
     {"X-API-Key", api_key}]
  end

end
