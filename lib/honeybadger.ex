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
        use_logger: true,
        notice_filter: Honeybadger.DefaultNoticeFilter,
        filter: Honeybadger.DefaultFilter,
        filter_keys: [:password, :credit_card]

  ### Notifying

  If you use `Honeybadger.Plug` and `Honeybadger.Logger` included in this
  library you won't need to use `Honeybadger.notify/3` for manual reporting
  very often. However, if you need to send custom notifications you can do so:

      try do
        raise RunTimeError, message: "Oops"
      rescue
        exception ->
          metadata = %{user_id: 1, account: "A Very Important Customer"}
          Honeybadger.notify(exception, metadata)
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
        filter: Honeybadger.DefaultFilter,
        filter_keys: [:password, :credit_card]

  This will remove any entries in the context, session, cgi_data and
  params that match one of the filter keys. The check is case insensitive
  and matches atoms or strings.

  If the `DefaultFilter` does not suit your needs, you can implement your
  own filter. A simple filter looks like:

      defmodule MyApp.MyFilter do
        use Honeybadger.FilterMixin

        # drop password fields out of the context Map
        def filter_context(context), do: Map.drop(context, [:password])

        # remove secrets from an error message
        def filter_error_message(message),
          do: Regex.replace(~r/Secret: \w+/, message, "Secret: ***")
      end

  See `Honeybadger.Filter` for details on implementing your own filter.
  """

  use Application

  alias Honeybadger.{Backtrace, Client, Notice}

  defmodule MissingEnvironmentNameError do
    defexception message: """
    The environment_name setting is required so that we can report the correct
    environment name to Honeybadger. Please configure environment_name in your
    config.exs and environment specific config files to have accurate reporting
    of errors.

    config :honeybadger, :environment_name, :dev
    """
  end

  @context :honeybadger_context

  @doc false
  def start(_type, _opts) do
    import Supervisor.Spec

    config =
      get_all_env()
      |> put_dynamic_env()
      |> verify_environment_name!()
      |> persist_all_env()

    if config[:use_logger] do
      :error_logger.add_report_handler(Honeybadger.Logger)
    end

    children = [
      worker(Client, [config])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Send an exception notification, if reporting is enabled.

  This is the primary way to do manual error reporting and it is also used
  internally to deliver logged errors.

  ## Example

      try do
        do_something_risky()
      rescue
        exception ->
          Honeybadger.notify(exception)
      end

  If desired additional metadata can be provided as well:

      Honeybadger.notify(%MyException{}, %{culprit_id: 123})
      #=> :ok
  """
  @spec notify(Exception.t, Map.t, list()) :: :ok
  def notify(exception, metadata \\ %{}, stacktrace \\ nil) do
    exception
    |> Notice.new(contextual_metadata(metadata), backtrace(stacktrace))
    |> Client.send_notice()
  end

  def context do
    (Process.get(@context) || %{}) |> Enum.into(Map.new)
  end

  def context(keyword_or_map) do
    Process.put(@context, Map.merge(context(), Enum.into(keyword_or_map, %{})))
    context()
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
        System.get_env(var) || raise ArgumentError, "system variable #{inspect(var)} is not set"
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

  defp put_dynamic_env(config) do
    hostname = fn ->
      :inet.gethostname()
      |> elem(1)
      |> List.to_string()
    end

    config
    |> Keyword.put_new_lazy(:hostname, hostname)
    |> Keyword.put_new_lazy(:project_root, &System.cwd/0)
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

  defp backtrace(nil) do
    backtrace(System.stacktrace())
  end
  defp backtrace([]) do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    backtrace(stacktrace)
  end
  defp backtrace(stacktrace) do
    Backtrace.from_stacktrace(stacktrace)
  end

  defp contextual_metadata(%{context: _} = metadata) do
    metadata
  end
  defp contextual_metadata(metadata) do
    %{context: metadata}
  end
end
