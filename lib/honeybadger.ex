defmodule Honeybadger do
  @moduledoc """
  This module contains the notify macro and context function you can use in
  your applications.

  ### Configuring

  By default the HONEYBADGER_API_KEY environment variable is used to find
  your API key for Honeybadger. You can also manually set your API key by
  configuring the :honeybadger application. You can see the default
  configuration in the default_config/0 private function at the bottom of
  this file.

      config :honeybadger,
        api_key: "mysupersecretkey",
        environment_name: :prod,
        app: :my_app_name,
        exclude_envs: [:dev, :test],
        hostname: "myserver.domain.com",
        origin: "https://api.honeybadger.io",
        proxy: "http://proxy.net:PORT",
        proxy_auth: {"Username", "Password"},
        project_root: "/home/skynet",
        revision: System.get_env("GIT_REVISION"),
        use_logger: true,
        notice_filter: Honeybadger.NoticeFilter.Default,
        filter: Honeybadger.Filter.Default,
        filter_keys: [:password, :credit_card]

  ### Notifying

  If you use `Honeybadger.Plug` and `Honeybadger.Logger` included in this
  library you won't need to use `Honeybadger.notify/3` for manual reporting
  very often. However, if you need to send custom notifications you can do so:

      try do
        raise RunTimeError, message: "Oops"
      rescue
        exception ->
          context = %{user_id: 1, account: "A Very Important Customer"}

          Honeybadger.notify(exception, context, __STACKTRACE__)
      end

  Note that `notify` may be used outside of `try`, but it will use a different
  mechanism for getting the current stacktrace. The resulting stacktrace may be
  noisier and less accurate.

  ### Setting Context

  You can add an arbitrary map of context that will get sent to the Honeybadger
  API when/if an exception occurs in that process. Do keep in mind the process
  dictionary is used for retrieving this context so try not to put large data
  structures in the context.

      Honeybadger.context(user_id: 1, account: "My Favorite Customer")
      Honeybadger.context(%{user_id: 2, account: "That Needy Customer")

  ### Using the Plug

  If you're using Phoenix, or any Plug-based Elixir web framework, you can
  `use` the `Honeybadger.Plug` module in your Router and all exceptions in web
  requests will automatically be reported to Honeybadger.

      defmodule MoneyPrinter.Router do
        use MoneyPrinter.Web, :router
        use Honeybadger.Plug
      end

  You can also automatically set useful context on every request by defining
  a Plug compatible function:

      defmodule MoneyPrinter.Router do
        use MoneyPrinter.Web, :router
        use Honeybadger.Plug

        plug :set_honeybadger_context

        # your routes

        defp set_honeybadger_context(conn, _opts) do
          user = get_user(conn)
          Honeybadger.context(user_id: user.id, account: user.account)
          conn
        end
      end

  ### Using the Error Logger

  By default the logger is enabled. The logger will automatically receive any
  error reports for SASL compliant processes such as GenServers, GenEvents,
  Agents, Tasks and any process spawned using `proc_lib`. You can disable the
  logger by setting `use_logger` to false in your Honeybadger config.

  ### Using a Notification Filter

  Before data is sent to Honeybadger, it is run through a filter which can
  remove sensitive fields or do other processing on the data. For basic
  filtering the default configuration is equivalent to:

      config :honeybadger,
        filter: Honeybadger.Filter.Default,
        filter_keys: [:password, :credit_card]

  This will remove any entries in the context, session, cgi_data and
  params that match one of the filter keys. The check is case insensitive
  and matches atoms or strings.

  If the `Filter.Default` does not suit your needs, you can implement your
  own filter. A simple filter looks like:

      defmodule MyApp.MyFilter do
        use Honeybadger.Filter.Mixin

        # drop password fields out of the context Map
        def filter_context(context), do: Map.drop(context, [:password])

        # remove secrets from an error message
        def filter_error_message(message),
          do: Regex.replace(~r/Secret: \w+/, message, "Secret: ***")
      end

  See `Honeybadger.Filter` for details on implementing your own filter.

  ### Adding Breadcrumbs

  Breadcrumbs allow you to record events along a processes execution path. If
  an error is thrown, the set of breadcrumb events will be sent along with the
  notice. These breadcrumbs can contain useful hints while debugging.

  Ensure that you enable breadcrumbs in the config (as it is disabled by
  default):

      config :honeybadger,
        breadcrumbs_enabled: true

  See `Honeybadger.add_breadcrumb` for more information.
  """

  use Application

  alias Honeybadger.{Client, Notice}
  alias Honeybadger.Breadcrumbs.{Collector, Breadcrumb}

  defmodule MissingEnvironmentNameError do
    defexception message: """
                 The environment_name setting is required so that we can report the correct
                 environment name to Honeybadger. Please configure environment_name in your
                 config.exs and environment specific config files to have accurate reporting
                 of errors.

                 config :honeybadger, :environment_name, :dev
                 """
  end

  @doc false
  def start(_type, _opts) do
    import Supervisor.Spec

    config =
      get_all_env()
      |> put_dynamic_env()
      |> verify_environment_name!()
      |> persist_all_env()

    if config[:use_logger] do
      _ = Logger.add_backend(Honeybadger.Logger)
    end

    Honeybadger.Breadcrumbs.Telemetry.attach()

    children = [
      worker(Client, [config])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Send an exception notification, if reporting is enabled.

  This is the primary way to do manual error reporting and it is also used
  internally to deliver logged errors.

  ## Stacktrace

  Accessing the stacktrace outside of a rescue/catch is deprecated. Notifiations should happen
  inside of a rescue/catch block so that the stacktrace can be provided with `__STACKTRACE__`.
  Stacktraces _must_ be provided and won't be automatically extracted from the current process.

  ## Example

      try do
        do_something_risky()
      rescue
        exception ->
          Honeybadger.notify(exception, %{}, __STACKTRACE__)
      end

  Send a notification directly from a string, which will be sent as a
  `RuntimeError`:

      iex> Honeybadger.notify("custom error message")
      :ok

  Send a notification as a `class` and `message`:

      iex> Honeybadger.notify(%{class: "SpecialError", message: "custom message"})
      :ok

  Send a notification as a `badarg` atom:

      iex> Honeybadger.notify(:badarg)
      :ok

  If desired additional metadata can be provided as well:

      iex> Honeybadger.notify(%RuntimeError{}, %{culprit_id: 123})
      :ok
  """
  @spec notify(Notice.noticeable(), map(), list()) :: :ok
  def notify(exception, metadata \\ %{}, stacktrace \\ []) do
    # Grab process local breadcrumbs if not passed with call and add notice breadcrumb
    breadcrumbs =
      metadata
      |> Map.get(:breadcrumbs, Collector.breadcrumbs())
      |> Collector.put(notice_breadcrumb(exception))
      |> Collector.output()

    metadata_with_breadcrumbs =
      metadata
      |> contextual_metadata()
      |> Map.put(:breadcrumbs, breadcrumbs)

    exception
    |> Notice.new(metadata_with_breadcrumbs, stacktrace)
    |> Client.send_notice()
  end

  @doc """
  Stores a breadcrumb item.

  In the case of an error, the set of breadcrumbs (trail) will be reported
  along side the notice to help with debugging.

  Breadcrumbs are stored along with the logger context, referenced by the
  calling process. If you are sending messages between processes, breadcrumbs
  will not transfer automatically. Since a typical system might have many
  processes, it is advised that you be conservative when storing breadcrumbs as
  each breadcrumb consumes memory.

  ## Example

      Honeybadger.add_breadcrumb("Email Sent", metadata: %{
        user: user.id, message: message
      })
      => :ok
  """
  @spec add_breadcrumb(String.t(), [{:metadata, map()} | {:category, String.t()}]) :: :ok
  def add_breadcrumb(message, opts \\ []) when is_binary(message) and is_list(opts) do
    Collector.add(Breadcrumb.new(message, opts))
  end

  @doc """
  Retrieves the context that will be sent to the Honeybadger API when an exception occurs in the
  current process.

  Context is stored as Logger metadata, and is in fact an alias for `Logger.metadata/0`.
  """
  @spec context() :: map()
  def context do
    Logger.metadata() |> Map.new() |> Map.delete(Collector.metadata_key())
  end

  @doc """
  Store additional context in the process metadata.

  This function will merge the given map or keyword list into the existing metadata, with the
  exception of setting a key to `nil`, which will remove that key from the metadata.

  Context is stored as Logger metadata.
  """
  @spec context(map() | keyword()) :: map()
  def context(map) when is_map(map), do: context(Keyword.new(map))

  def context(keyword) do
    Logger.metadata(keyword)

    context()
  end

  @doc """
  Clears the context.

  Note that because context is stored as logger metadata, clearing the context will clear _all_
  metadata.
  """
  @spec clear_context() :: :ok
  def clear_context do
    Logger.reset_metadata()

    :ok
  end

  @doc """
  Fetch configuration specific to the :honeybadger application.

  ## Example

      Honeybadger.get_env(:exclude_envs)
      #=> [:dev, :test]
  """
  @spec get_env(atom) :: any | no_return
  def get_env(key) when is_atom(key) do
    case Application.fetch_env(:honeybadger, key) do
      {:ok, {:system, var}} when is_binary(var) ->
        System.get_env(var)

      {:ok, value} ->
        value

      :error ->
        raise ArgumentError, "the configuration parameter #{inspect(key)} is not set"
    end
  end

  @doc """
  Fetch all configuration specific to the :honeybadger application.

  This resolves values the same way that `get_env/1` does, so it resolves
  :system tuple variables correctly.

  ## Example

      Honeybadger.get_all_env()
      #=> [api_key: "12345", environment_name: "dev", ...]
  """
  @spec get_all_env() :: [{atom, any}]
  def get_all_env do
    for {key, _value} <- Application.get_all_env(:honeybadger) do
      {key, get_env(key)}
    end
  end

  # Helpers

  # Allows for Notice breadcrumb to have custom text as message if an error is
  # not passed to the notice function. We can assume if it was passed an error
  # then there will be an error breadcrumb right before this one.
  defp notice_breadcrumb(exception) do
    reason =
      case exception do
        title when is_binary(title) ->
          title

        error when is_atom(error) and not is_nil(error) ->
          :error
          |> Exception.normalize(error)
          |> Map.get(:message, to_string(error))

        _ ->
          nil
      end

    ["Honeybadger Notice", reason]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(": ")
    |> Breadcrumb.new(category: "notice")
  end

  defp put_dynamic_env(config) do
    hostname = fn ->
      :inet.gethostname()
      |> elem(1)
      |> List.to_string()
    end

    config
    |> Keyword.put_new_lazy(:hostname, hostname)
    |> Keyword.put_new_lazy(:project_root, &File.cwd!/0)
    |> Keyword.put_new(:revision, nil)
  end

  defp verify_environment_name!(config) do
    case Keyword.get(config, :environment_name) do
      nil -> raise MissingEnvironmentNameError
      _ -> config
    end
  end

  defp persist_all_env(config) do
    Enum.each(config, fn {key, value} ->
      Application.put_env(:honeybadger, key, value)
    end)

    config
  end

  defp contextual_metadata(%{context: _} = metadata) do
    metadata
  end

  defp contextual_metadata(metadata) do
    %{context: metadata}
  end
end
