defmodule Honeybadger.Client do
  alias Poison, as: JSON

  defstruct [:active?, :environment_name, :headers, :hostname, :origin, :proxy,
             :proxy_auth]

  @notices_endpoint "/v1/notices"
  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def new do
    api_key = Honeybadger.get_env(:api_key)
    env_name = Honeybadger.get_env(:environment_name)
    exclude_envs = Honeybadger.get_env(:exclude_envs)
    hostname = Honeybadger.get_env(:hostname)
    origin = Honeybadger.get_env(:origin)
    proxy = Honeybadger.get_env(:proxy)
    proxy_auth = Honeybadger.get_env(:proxy_auth)

    %__MODULE__{active?: !Enum.member?(exclude_envs, env_name),
                origin: origin,
                headers: headers(api_key),
                environment_name: env_name,
                hostname: hostname,
                proxy: proxy,
                proxy_auth: proxy_auth}
  end

  def send_notice(%__MODULE__{} = client, notice, http_mod \\ HTTPoison) do
    do_send_notice(client, JSON.encode!(notice), http_mod)
  end

  defp do_send_notice(%{active?: false}, _notice, _http_mod) do
    {:ok, :unsent}
  end
  defp do_send_notice(%{proxy: nil} = client, notice, http_mod) do
    http_mod.post(client.origin <> @notices_endpoint,
                  notice,
                  client.headers)
  end
  defp do_send_notice(client, notice, http_mod) do
    http_mod.post(client.origin <> @notices_endpoint,
                  notice,
                  client.headers,
                  [proxy: client.proxy, proxy_auth: client.proxy_auth])
  end

  defp headers(api_key) do
    [{"X-API-Key", api_key}] ++ @headers
  end
end
