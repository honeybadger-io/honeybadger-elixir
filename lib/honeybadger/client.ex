defmodule Honeybadger.Client do
  alias Poison, as: JSON

  defstruct [:environment_name, :headers, :hostname, :origin, :proxy, :proxy_auth]

  @metrics_endpoint "/v1/metrics"
  @notices_endpoint "/v1/notices"

  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def new do
    origin = Application.get_env(:honeybadger, :origin)
    api_key = Application.get_env(:honeybadger, :api_key)
    env_name = Application.get_env(:honeybadger, :environment_name)
    hostname = Application.get_env(:honeybadger, :hostname)
    proxy = Application.get_env(:honeybadger, :proxy)
    proxy_auth = Application.get_env(:honeybadger, :proxy_auth)
    %__MODULE__{origin: origin,
                headers: headers(api_key),
                environment_name: env_name,
                hostname: hostname,
                proxy: proxy,
                proxy_auth: proxy_auth}
  end

  def send_metric(%__MODULE__{} = client, metric, http_mod \\ HTTPoison) do
    body = JSON.encode!(%{
      environment: client.environment_name,
      hostname: client.hostname,
      metrics: metric
    })

    post(client, @metrics_endpoint, body, http_mod)
  end

  def send_notice(%__MODULE__{} = client, metric, http_mod \\ HTTPoison) do
    body = JSON.encode!(metric)

    post(client, @notices_endpoint, body, http_mod)
  end

  defp post(client, url, body, http_mod) do
    proxy = [proxy: client.proxy, proxy_auth: client.proxy_auth]

    case client.proxy do
      nil -> http_mod.post(client.origin <> url, body, client.headers)
      _ -> http_mod.post(client.origin <> url, body, client.headers, proxy)
    end
  end

  defp headers(api_key) do
    @headers ++ [{"X-API-Key", api_key}]
  end
end
