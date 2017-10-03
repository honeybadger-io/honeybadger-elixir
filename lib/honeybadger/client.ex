defmodule Honeybadger.Client do
  alias Poison, as: JSON

  defstruct [:environment_name, :headers, :hostname, :origin, :proxy, :proxy_auth]

  @notices_endpoint "/v1/notices"
  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def new do
    origin = Honeybadger.get_env(:origin)
    api_key = Honeybadger.get_env(:api_key)
    env_name = Honeybadger.get_env(:environment_name)
    hostname = Honeybadger.get_env(:hostname)
    proxy = Honeybadger.get_env(:proxy)
    proxy_auth = Honeybadger.get_env(:proxy_auth)

    %__MODULE__{origin: origin,
                headers: headers(api_key),
                environment_name: env_name,
                hostname: hostname,
                proxy: proxy,
                proxy_auth: proxy_auth}
  end

  def send_notice(%__MODULE__{} = client, notice, http_mod \\ HTTPoison) do
    encoded_notice = JSON.encode!(notice)
    do_send_notice(client, encoded_notice, http_mod, active_environment?())
  end

  defp do_send_notice(_client, _encoded_notice, _http_mod, false), do: {:ok, :unsent}
  defp do_send_notice(client, encoded_notice, http_mod, true) do
    case client.proxy do
      nil ->
        http_mod.post(
          client.origin <> @notices_endpoint, encoded_notice, client.headers
        )
      _ ->
        http_mod.post(
          client.origin <> @notices_endpoint, encoded_notice, client.headers,
          [proxy: client.proxy, proxy_auth: client.proxy_auth]
        )
    end
  end

  defp headers(api_key) do
    [{"X-API-Key", api_key}] ++ @headers
  end

  defp active_environment? do
    env = Honeybadger.get_env(:environment_name)
    exclude_envs = Honeybadger.get_env(:exclude_envs)

    not env in exclude_envs
  end
end
