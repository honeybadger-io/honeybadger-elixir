defmodule Honeybadger do
  use Application
  alias Honeybadger.Backtrace
  alias Honeybadger.Client
  alias Honeybadger.Notice
  alias Honeybadger.Metric

  defmodule MissingEnvironmentNameError do
    defexception message: """
      The environment_name setting is required so that we can report the
      correct environment name to Honeybadger. Please configure
      environment_name in your config.exs and environment specific config files
      to have accurate reporting of errors.

      config :honeybadger, :environment_name, :dev
    """
  end

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
          project_root: "/home/skynet",
          use_logger: true,
          notice_filter: Honeybadger.DefaultNoticeFilter,
          filter: Honeybadger.DefaultFilter,
          filter_keys: [:password, :credit_card]

    ### Notifying
    Honeybadger.notify is a macro so that it can be wiped away in environments
    that you don't need exception monitoring in such as dev and test. If you use the
    Plug and Logger included in this library you won't need to use
    Honeybadger.notify very often. Here is an example:

        exception = %RuntimeError{message: "Oops"}
        context = %{user_id: 1, account: "A Very Important Customer"}
        {:current_stacktrace, stacktrace} = Process.info(self, :current_stacktrace)
        Honeybadger.notify(exception, context, stacktrace)

    ### Setting Context
    You can add an arbitrary map of context that will get sent to the
    Honeybadger API when/if an exception occurs in that process. Do keep in
    mind the process dictionary is used for retrieving this context so try not
    to put large data structures in the context.

        Honeybadger.context(user_id: 1, account: "My Favorite Customer")
        Honeybadger.context(%{user_id: 2, account: "That Needy Customer")

    ### Using the Plug
    If you're using Phoenix, or any Plug-based Elixir web framework, you can
    `use` the Honeybadger.Plug module in your Router and all exceptions in web
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


    ### Using the error logger
    By default the logger is enabled. The logger will
    automatically receive any error reports for SASL compliant
    processes such as GenServers, GenEvents, Agents, Tasks and
    any process spawned using `proc_lib`. You can disable the
    logger by setting `use_logger` to false in your
    Honeybadger config.

    ### Using a notification filter
    Before data is sent to Honeybadger, it is run through a filter which
    can remove sensitive fields or do other processing on the data.  For
    basic filtering the default configuration is equivalent to:

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

    See the `Honeybadger.FilterMixin` module doc for details on implementing
    your own filter.
  """

  @context :honeybadger_context

  @doc """
    This is here as a callback to Application to configure and start the
    Honeybadger client's dependencies. You'll likely never need to call this
    function yourself.
  """
  def start(_type, _opts) do
    require_environment_name!()

    app_config = Application.get_all_env(:honeybadger)
    config = Keyword.merge(default_config(), app_config)
    update_application_config!(config)

    if config[:use_logger] do
      :error_logger.add_report_handler(Honeybadger.Logger)
    end

    Honeybadger.Metrics.Supervisor.start_link
  end

  defmacro notify(exception) do
    macro_notify(exception, {:%{}, [], []}, [])
  end

  defmacro notify(exception, metadata) do
    macro_notify(exception, metadata, [])
  end

  defmacro notify(exception, metadata, stacktrace) do
    macro_notify(exception, metadata, stacktrace)
  end

  defp macro_notify(exception, metadata, stacktrace) do
    if active_environment? do
      quote do
        Task.start fn ->
          Honeybadger.do_notify(unquote(exception), unquote(metadata), unquote(stacktrace))
        end
      end
    else
      quote do
        [_, _, _] = [unquote(exception), unquote(metadata), unquote(stacktrace)]
        :ok
      end
    end
  end

  def active_environment? do
    env = Application.get_env(:honeybadger, :environment_name)
    exclude_envs = Application.get_env(:honeybadger, :exclude_envs, [:dev, :test])
    not env in exclude_envs
  end

  def do_notify(exception, metadata, []) do
      {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
      do_notify(exception, metadata, stacktrace)
  end

  def do_notify(exception, %{context: _} = metadata, stacktrace) do
    client = Client.new
    backtrace = Backtrace.from_stacktrace(stacktrace)
    notice = Notice.new(exception, metadata, backtrace)
    Client.send_notice(client, notice)
  end

  def do_notify(exception, metadata, stacktrace) do
    metadata = %{context: metadata}
    do_notify(exception, metadata, stacktrace)
  end

  def send_metric(%Metric{} = metric) do
    if active_environment? do
      client = Client.new
      Client.send_metric(client, metric, HTTPoison)
    else
      :ok
    end
  end

  def context do
    (Process.get(@context) || %{}) |> Enum.into(Map.new)
  end

  def context(dict) do
    Process.put(@context, Dict.merge(context(), dict))
    context()
  end

  defp default_config do
     [api_key: System.get_env("HONEYBADGER_API_KEY"),
      exclude_envs: [:dev, :test],
      hostname: :inet.gethostname |> elem(1) |> List.to_string,
      origin: "https://api.honeybadger.io",
      project_root: System.cwd,
      use_logger: true,
      notice_filter: Honeybadger.DefaultNoticeFilter,
      filter: Honeybadger.DefaultFilter,
      filter_keys: [:password, :credit_card],
      filter_disable_url: false,
      filter_disable_params: false,
      filter_disable_session: false]
  end

  defp require_environment_name! do
    if is_nil(Application.get_env(:honeybadger, :environment_name)) do
      case System.get_env("MIX_ENV") do
        nil ->
          raise MissingEnvironmentNameError
        env ->
          Application.put_env(:honeybadger, :environment_name, String.to_atom(env))
      end
    end
  end

  defp update_application_config!(config) do
    Enum.each(config, fn({key, value}) ->
      Application.put_env(:honeybadger, key, value)
    end)
  end
end
