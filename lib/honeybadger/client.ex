defmodule Honeybadger.Client do
  alias Poison, as: JSON

  defstruct [:environment_name, :headers, :hostname, :origin]

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

  def send_notice(%__MODULE__{} = client, notice, http_mod \\ HTTPoison, active_environment) do
    encoded_notice = JSON.encode!(notice)
    do_send_notice(client, encoded_notice, http_mod, active_environment)
  end
  defp do_send_notice(_client, _encoded_notice, _http_mod, false), do: {:ok, :unsent}
  defp do_send_notice(client, encoded_notice, http_mod, true) do
    http_mod.post(
      client.origin <> @notices_endpoint, encoded_notice, client.headers
    )
  end

  defp headers(api_key) do
    [{"Accept", "application/json"},
     {"Content-Type", "application/json"},
     {"X-API-Key", api_key}]
  end

end
