defmodule Honeybadger.Client do
  @moduledoc false

  use GenServer

  require Logger

  alias Honeybadger.Breadcrumbs.{RingBuffer, Breadcrumb}

  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"},
    {"User-Agent", "Honeybadger Elixir"}
  ]
  @max_connections 20
  @notices_endpoint "/v1/notices"

  # State

  @buffer_impl RingBuffer

  @type t :: %__MODULE__{
          breadcrumbs: @buffer_impl.t(),
          breadcrumbs_enabled: boolean(),
          api_key: binary(),
          enabled: boolean(),
          headers: [{binary(), term()}],
          proxy: binary(),
          proxy_auth: {binary(), binary()},
          url: binary()
        }

  defstruct [
    :breadcrumbs,
    :breadcrumbs_enabled,
    :api_key,
    :enabled,
    :headers,
    :proxy,
    :proxy_auth,
    :url
  ]

  # API

  @doc false
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, new(opts), name: __MODULE__)
  end

  @doc false
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    %__MODULE__{
      breadcrumbs: @buffer_impl.new(40),
      breadcrumbs_enabled: get_env(opts, :breadcrumbs_enabled),
      api_key: get_env(opts, :api_key),
      enabled: enabled?(opts),
      headers: build_headers(opts),
      proxy: get_env(opts, :proxy),
      proxy_auth: get_env(opts, :proxy_auth),
      url: get_env(opts, :origin) <> @notices_endpoint
    }
  end

  @doc false
  def with_pid(op, f) do
    if pid = Process.whereis(__MODULE__) do
      f.(pid)
    else
      Logger.warn(fn ->
        "[Honeybadger] Unable to #{op}, the :honeybadger client isn't running"
      end)
    end
  end

  @doc false
  @spec send_notice(map()) :: :ok | {:error, term()}
  def send_notice(notice) when is_map(notice) do
    with_pid("notify", fn pid -> GenServer.cast(pid, {:notice, notice}) end)
  end

  @doc false
  @breadcrumb_defaults [metadata: %{}, category: "custom"]
  @spec add_breadcrumb(String.t(), metadata: map(), category: String.t()) ::
          :ok | {:error, term()}
  def add_breadcrumb(message, opts \\ []) do
    with_pid("add breadcrumb", fn pid ->
      GenServer.call(
        pid,
        {:breadcrumb, Breadcrumb.new(message, Enum.into(opts, @breadcrumb_defaults))}
      )
    end)
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
  @spec enabled?(Keyword.t()) :: boolean
  def enabled?(opts) do
    env_name = get_env(opts, :environment_name)
    excluded = get_env(opts, :exclude_envs)

    not (maybe_to_atom(env_name) in excluded)
  end

  # Callbacks

  @impl GenServer
  def init(%__MODULE__{} = state) do
    warn_if_incomplete_env(state)
    warn_in_dev_mode(state)

    :ok = :hackney_pool.start_pool(__MODULE__, max_connections: @max_connections)

    {:ok, state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok = :hackney_pool.stop_pool(__MODULE__)
  end

  @impl GenServer
  def handle_cast({:notice, _notice}, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast({:notice, _notice}, %{api_key: nil} = state) do
    {:noreply, state}
  end

  def handle_cast(
        {:notice, notice},
        %{
          enabled: true,
          url: url,
          headers: headers,
          breadcrumbs: breadcrumbs,
          breadcrumbs_enabled: breadcrumbs_enabled
        } = state
      ) do
    notice_with_breadcrumbs =
      Map.put(notice, :breadcrumbs, %{
        enabled: breadcrumbs_enabled,
        trail: @buffer_impl.to_list(breadcrumbs)
      })

    case Honeybadger.JSON.encode(notice_with_breadcrumbs) do
      {:ok, payload} ->
        opts =
          state
          |> Map.take([:proxy, :proxy_auth])
          |> Enum.into(Keyword.new())
          |> Keyword.put(:pool, __MODULE__)

        post_notice(url, headers, payload, opts)

      {:error, %Jason.EncodeError{message: message}} ->
        Logger.warn(fn -> "[Honeybadger] Notice encoding failed: #{message}" end)
    end

    {:noreply, state}
  end

  def handle_call({:breadcrumb, _}, _from, %{breadcrumbs_enabled: false} = state) do
    {:reply, :ignored, state}
  end

  def handle_call({:breadcrumb, breadcrumb}, _from, state) do
    {:reply, :ok, Map.update!(state, :breadcrumbs, &@buffer_impl.add(&1, breadcrumb))}
  end

  @impl GenServer
  def handle_info(message, state) do
    Logger.info(fn -> "[Honeybadger] unexpected message: #{inspect(message)}" end)

    {:noreply, state}
  end

  # API Integration

  defp build_headers(opts) do
    [{"X-API-Key", get_env(opts, :api_key)}] ++ @headers
  end

  defp post_notice(url, headers, payload, opts) do
    case :hackney.post(url, headers, payload, opts) do
      {:ok, code, _headers, ref} when code in 200..399 ->
        body = body_from_ref(ref)
        Logger.debug(fn -> "[Honeybadger] API success: #{inspect(body)}" end)

      {:ok, code, _headers, ref} when code in 400..599 ->
        body = body_from_ref(ref)
        Logger.error(fn -> "[Honeybadger] API failure: #{inspect(body)}" end)

      {:error, reason} ->
        Logger.error(fn -> "[Honeybadger] connection error: #{inspect(reason)}" end)
    end
  end

  defp body_from_ref(ref) do
    ref
    |> :hackney.body()
    |> elem(1)
  end

  # Incomplete Env

  defp get_env(opts, key) do
    Keyword.get(opts, key, Honeybadger.get_env(key))
  end

  defp maybe_to_atom(value) when is_binary(value), do: String.to_atom(value)
  defp maybe_to_atom(value), do: value

  @mandatory_keys ~w(api_key environment_name)a
  defp warn_if_incomplete_env(%{enabled: true}) do
    for key <- @mandatory_keys do
      unless Honeybadger.get_env(key) do
        Logger.error(fn ->
          "[Honeybadger] Mandatory config key :#{key} not set"
        end)
      end
    end
  end

  defp warn_if_incomplete_env(_state), do: :ok

  defp warn_in_dev_mode(%{enabled: false}) do
    Logger.info(fn ->
      "[Honeybadger] Development mode is enabled. " <>
        "Data will not be reported until you deploy your app."
    end)
  end

  defp warn_in_dev_mode(_state), do: :ok
end
