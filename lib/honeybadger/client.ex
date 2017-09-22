defmodule Honeybadger.Client do
  @moduledoc false

  use GenServer

  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"},
    {"User-Agent", "Honeybadger Elixir"}
  ]
  @max_connections 20
  @notices_endpoint "/v1/notices"

  # State

  defstruct [:enabled, :headers, :proxy, :proxy_auth, :url]

  # API

  def start_link(config_opts) do
    state = new(config_opts)

    GenServer.start_link(__MODULE__, state, [name: __MODULE__])
  end

  @doc false
  def new(opts) do
    %__MODULE__{enabled: enabled?(opts),
                headers: build_headers(opts),
                proxy: get_env(opts, :proxy),
                proxy_auth: get_env(opts, :proxy_auth),
                url: get_env(opts, :origin) <> @notices_endpoint}
  end

  @doc false
  def send_notice(notice) when is_map(notice) do
    if pid = Process.whereis(__MODULE__) do
      GenServer.cast(pid, {:notice, notice})
    else
      IO.puts "SERVER NOT RUNNING"
    end
  end

  # Callbacks

  def init(state) do
    :ok = :hackney_pool.start_pool(__MODULE__, [max_connections: @max_connections])

    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok = :hackney_pool.stop_pool(__MODULE__)
  end

  def handle_cast({:notice, _notice}, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast({:notice, notice}, %{enabled: true} = state) do
    payload = Poison.encode!(notice)

    opts =
      state
      |> Map.take([:proxy, :proxy_auth])
      |> Enum.into(Keyword.new)
      |> Keyword.put(:pool, __MODULE__)

    :hackney.post(state.url, state.headers, payload, opts)

    {:noreply, state}
  end

  # Helpers

  def enabled?(opts) do
    env_name = get_env(opts, :environment_name)
    excluded = get_env(opts, :exclude_envs)

    not env_name in excluded
  end

  defp build_headers(opts) do
    [{"X-API-Key", get_env(opts, :api_key)}] ++ @headers
  end

  defp get_env(opts, key) do
    Keyword.get(opts, key, Honeybadger.get_env(:api_key))
  end
end
