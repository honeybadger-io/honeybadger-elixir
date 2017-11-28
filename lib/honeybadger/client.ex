defmodule Honeybadger.Client do
  @moduledoc false

  use GenServer

  require Logger

  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"},
    {"User-Agent", "Honeybadger Elixir"}
  ]
  @max_connections 20
  @notices_endpoint "/v1/notices"

  # State

  defstruct [:api_key, :enabled, :headers, :proxy, :proxy_auth, :url]

  # API

  def start_link(config_opts) do
    state = new(config_opts)

    GenServer.start_link(__MODULE__, state, [name: __MODULE__])
  end

  @doc false
  def new(opts) do
    %__MODULE__{enabled: enabled?(opts),
                api_key: get_env(opts, :api_key),
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
      Logger.warn("[Honeybadger] Unable to notify, the :honeybadger client isn't running")
    end
  end

  @doc """
  Check whether reporting is enabled for the current environment.

  ## Example

      iex> Honeybadger.Client.enabled?(environment_name: :dev, exclude_envs: [:test, :dev])
      false

      iex> Honeybadger.Client.enabled?(environment_name: "dev", exclude_envs: [:test, :dev])
      false

      iex> Honeybadger.Client.enabled?(environment_name: :dev, exclude_envs: [:test])
      true

      iex> Honeybadger.Client.enabled?(environment_name: "unexpected", exclude_envs: [:test])
      true
  """
  @spec enabled?(Keyword.t) :: boolean
  def enabled?(opts) do
    env_name = get_env(opts, :environment_name)
    excluded = get_env(opts, :exclude_envs)

    not maybe_to_atom(env_name) in excluded
  end

  # Callbacks

  def init(state) do
    warn_if_incomplete_env(state)
    warn_in_dev_mode(state)
    :ok = :hackney_pool.start_pool(__MODULE__, [max_connections: @max_connections])

    {:ok, state}
  end

  @mandatory_keys ~w[api_key environment_name]a
  defp warn_if_incomplete_env(%{enabled: true}) do
    @mandatory_keys
    |> Enum.each(fn key ->
      if !Honeybadger.get_env(key) do
        Logger.error("mandatory :honeybadger config key #{key} not set")
      end
    end)
  end
  defp warn_if_incomplete_env(_), do: :ok

  defp warn_in_dev_mode(%{enabled: false}) do
    Logger.warn(
      "Development mode is enabled. Data will not be reported until you deploy your app."
    )
  end

  defp warn_in_dev_mode(_), do: :ok

  def terminate(_reason, _state) do
    :ok = :hackney_pool.stop_pool(__MODULE__)
  end

  def handle_cast({:notice, _notice}, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast({:notice, _notice}, %{api_key: nil} = state) do
    {:noreply, state}
  end

  def handle_cast({:notice, notice}, %{enabled: true} = state) do
    payload = Poison.encode!(notice)

    opts =
      state
      |> Map.take([:proxy, :proxy_auth])
      |> Enum.into(Keyword.new)
      |> Keyword.put(:pool, __MODULE__)

    case :hackney.post(state.url, state.headers, payload, opts) do
      {:ok, code, _headers, ref} when code >= 200 and code <= 399 ->
        Logger.debug("[Honeybadger] API success: #{inspect(body_from_ref(ref))}")
      {:ok, code, _headers, ref} when code >= 400 and code <= 504 ->
        Logger.error("[Honeybadger] API failure: #{inspect(body_from_ref(ref))}")
      {:error, reason} ->
        Logger.error("[Honeybadger] connection error: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.info("[Honeybadger] unexpected message: #{inspect(message)}")

    {:noreply, state}
  end

  # Helpers

  defp body_from_ref(ref) do
    ref
    |> :hackney.body()
    |> elem(1)
  end

  defp build_headers(opts) do
    [{"X-API-Key", get_env(opts, :api_key)}] ++ @headers
  end

  defp get_env(opts, key) do
    Keyword.get(opts, key, Honeybadger.get_env(key))
  end

  defp maybe_to_atom(value) when is_binary(value) do
    String.to_atom(value)
  end

  defp maybe_to_atom(value) do
    value
  end
end
