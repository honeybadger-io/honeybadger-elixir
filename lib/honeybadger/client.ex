defmodule Honeybadger.Client do
  @moduledoc false

  use GenServer

  alias Honeybadger.{HTTPAdapter, HTTPAdapter.HTTPResponse}

  require Logger

  @external_resource version = Honeybadger.Mixfile.project()[:version]

  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"},
    {"User-Agent", "Honeybadger Elixir #{version}"}
  ]
  @notices_endpoint "/v1/notices"
  @events_endpoint "/v1/events"

  # State

  @type t :: %__MODULE__{
          api_key: binary(),
          enabled: boolean(),
          headers: [{binary(), term()}],
          proxy: binary(),
          proxy_auth: {binary(), binary()},
          url: binary(),
          event_url: binary(),
          hackney_opts: keyword()
        }

  defstruct [
    :api_key,
    :enabled,
    :headers,
    :proxy,
    :proxy_auth,
    :url,
    :event_url,
    :hackney_opts
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
      api_key: get_env(opts, :api_key),
      enabled: enabled?(opts),
      headers: build_headers(opts),
      proxy: get_env(opts, :proxy),
      proxy_auth: get_env(opts, :proxy_auth),
      url: get_env(opts, :origin) <> @notices_endpoint,
      event_url: get_env(opts, :origin) <> @events_endpoint,
      hackney_opts: get_env(opts, :hackney_opts)
    }
  end

  @doc false
  @spec send_notice(map()) :: :ok
  def send_notice(notice) when is_map(notice) do
    if pid = Process.whereis(__MODULE__) do
      GenServer.cast(pid, {:notice, notice})
    else
      Logger.warning(fn ->
        "[Honeybadger] Unable to notify, the :honeybadger client isn't running"
      end)
    end
  end

  @doc """
  Upload the event data
  """
  @spec send_event(map) :: :ok
  def send_event(event) when is_map(event) do
    if pid = Process.whereis(__MODULE__) do
      GenServer.cast(pid, {:event, event})
    else
      Logger.warning(fn ->
        "[Honeybadger] Unable to post event, the :honeybadger client isn't running"
      end)
    end
  end

  @doc """
  Send events in batches
  """
  @spec send_events(list) :: :ok | {:error, reason :: atom()}
  def send_events(events) when is_list(events) do
    if pid = Process.whereis(__MODULE__) do
      # 30 second timeout
      GenServer.call(pid, {:events, events}, 30_000)
    else
      Logger.warning(fn ->
        "[Honeybadger] Unable to post events, the :honeybadger client isn't running"
      end)

      {:error, :client_not_running}
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
  @spec enabled?(Keyword.t()) :: boolean
  def enabled?(opts) do
    env_name = get_env(opts, :environment_name)
    excluded = get_env(opts, :exclude_envs)

    maybe_to_atom(env_name) not in excluded
  end

  # Callbacks

  @impl GenServer
  def init(%__MODULE__{} = state) do
    warn_if_incomplete_env(state)
    warn_in_dev_mode(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:notice, _notice}, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast({:notice, _notice}, %{api_key: nil} = state) do
    {:noreply, state}
  end

  def handle_cast({:notice, notice}, %{enabled: true, url: url, headers: headers} = state) do
    case Honeybadger.JSON.encode(notice) do
      {:ok, payload} ->
        opts =
          state
          |> Map.take([:proxy, :proxy_auth])
          |> Enum.into(Keyword.new())
          |> Keyword.put(:pool, __MODULE__)

        hackney_opts =
          state
          |> Map.get(:hackney_opts)
          |> Keyword.merge(opts)

        post_payload(url, headers, payload, hackney_opts)

      {:error, %Jason.EncodeError{message: message}} ->
        Logger.warning(fn -> "[Honeybadger] Notice encoding failed: #{message}" end)

      {:error, %Protocol.UndefinedError{description: message}} ->
        Logger.warning(fn -> "[Honeybadger] Notice encoding failed: #{message}" end)
    end

    {:noreply, state}
  end

  def handle_cast({:event, _}, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_cast({:event, _}, %{api_key: nil} = state) do
    {:noreply, state}
  end

  def handle_cast(
        {:event, event},
        %{enabled: true, event_url: event_url, headers: headers} = state
      ) do
    case Honeybadger.JSON.encode(event) do
      {:ok, payload} ->
        opts =
          state
          |> Map.take([:proxy, :proxy_auth])
          |> Enum.into(Keyword.new())
          |> Keyword.put(:pool, __MODULE__)

        hackney_opts =
          state
          |> Map.get(:hackney_opts)
          |> Keyword.merge(opts)

        # post logic for events is the same as notices
        post_payload(event_url, headers, payload, hackney_opts)

      {:error, %Jason.EncodeError{message: message}} ->
        Logger.warning(fn -> "[Honeybadger] Event encoding failed: #{message}" end)

      {:error, %Protocol.UndefinedError{description: message}} ->
        Logger.warning(fn -> "[Honeybadger] Event encoding failed: #{message}" end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(message, state) do
    Logger.info(fn -> "[Honeybadger] unexpected message: #{inspect(message)}" end)

    {:noreply, state}
  end

  # Events
  #
  @impl GenServer
  def handle_call({:events, _}, _from, %{enabled: false} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:events, _}, _from, %{api_key: nil} = state) do
    {:reply, {:error, :no_api_key}, state}
  end

  def handle_call({:events, events}, _from, state) do
    %{event_url: event_url, headers: headers} = state
    # Convert each event to JSON and join with newlines
    encoded_events = Enum.map(events, &Honeybadger.JSON.encode/1)

    # Check if any encoding failed
    if Enum.any?(encoded_events, &match?({:error, _}, &1)) do
      {:reply, {:error, :encoding_error}, state}
    else
      payload = Enum.map_join(encoded_events, "\n", &elem(&1, 1))

      opts =
        state
        |> Map.take([:proxy, :proxy_auth])
        |> Map.put(:pool, __MODULE__)
        |> Keyword.new()

      hackney_opts =
        state
        |> Map.get(:hackney_opts)
        |> Keyword.merge(opts)

      headers =
        List.keyreplace(headers, "Content-Type", 0, {"Content-Type", "application/x-ndjson"})

      response =
        case HTTPAdapter.request(:post, event_url, payload, headers, hackney_opts) do
          {:ok, %HTTPResponse{body: body, status: status}} when status in 200..399 ->
            process_and_log_events_response(events, body)
            :ok

          {:ok, %HTTPResponse{status: status}} when status == 429 ->
            Logger.warning("[Honeybadger] Events API rate limited")
            {:error, :throttled}

          {:ok, %HTTPResponse{status: status}} when status in 400..599 ->
            Logger.warning("[Honeybadger] Events API failure with status: #{status}")
            {:error, :api_error}

          {:error, reason} ->
            Logger.warning(fn -> "[Honeybadger] Events connection error: #{inspect(reason)}" end)
            {:error, :connection_error}
        end

      {:reply, response, state}
    end
  end

  defp process_and_log_events_response(events, %{"errors" => true, "events" => res_events}) do
    Logger.debug("[Honeybadger] Events API (#{length(events)} events sent) with errors:")

    events
    |> Enum.zip(res_events)
    |> Enum.each(fn {event, %{"status" => status}} ->
      if status != 200 && status != 201 do
        Logger.warning(fn ->
          "[Honeybadger] Event error: #{status}\nEvent: #{inspect(event)}"
        end)
      end
    end)
  end

  defp process_and_log_events_response(events, %{"errors" => false}) do
    Logger.debug("[Honeybadger] Events API success (#{length(events)} events sent)")
  end

  defp process_and_log_events_response(_, _), do: nil

  # API Integration

  defp build_headers(opts) do
    [{"X-API-Key", get_env(opts, :api_key)}] ++ @headers
  end

  defp post_payload(url, headers, payload, hackney_opts) do
    case HTTPAdapter.request(:post, url, payload, headers, hackney_opts) do
      {:ok, %HTTPResponse{body: body, status: status}} when status in 200..399 ->
        Logger.debug(fn -> "[Honeybadger] API success: #{inspect(body)}" end)

      {:ok, %HTTPResponse{body: body, status: status}} when status == 429 ->
        Logger.warning(fn -> "[Honeybadger] API failure: #{inspect(body)}" end)

      {:ok, %HTTPResponse{body: body, status: status}} when status in 400..599 ->
        Logger.warning(fn -> "[Honeybadger] API failure: #{inspect(body)}" end)

      {:error, reason} ->
        Logger.warning(fn -> "[Honeybadger] connection error: #{inspect(reason)}" end)
    end
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
