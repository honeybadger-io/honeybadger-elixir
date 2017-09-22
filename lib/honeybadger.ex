defmodule Honeybadger do
  use Application

  alias Honeybadger.{Backtrace, Client, Notice}

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
          proxy: "http://proxy.net:PORT",
          proxy_auth: {"Username", "Password"},
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

  @doc false
  def start(_type, _opts) do
    import Supervisor.Spec

    config =
      :honeybadger
      |> Application.get_all_env()
      |> update_with_merged_config()
      |> verify_environment_name!()

    if config[:use_logger] do
      :error_logger.add_report_handler(Honeybadger.Logger)
    end

    children = [
      worker(Client, [config])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def notify(exception, metadata \\ %{}, stacktrace \\ []) do
    notice = Notice.new(exception,
                        contextual_metadata(metadata),
                        backtrace(stacktrace))

    Client.send_notice(notice)
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

  # Example

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

  # Helpers

  defp default_config do
     [api_key: {:system, "HONEYBADGER_API_KEY"},
      app: nil,
      environment_name: {:system, "MIX_ENV"},
      exclude_envs: [:dev, :test],
      hostname: :inet.gethostname |> elem(1) |> List.to_string,
      origin: "https://api.honeybadger.io",
      proxy: nil,
      proxy_auth: {nil, nil},
      project_root: System.cwd,
      use_logger: true,
      notice_filter: Honeybadger.DefaultNoticeFilter,
      filter: Honeybadger.DefaultFilter,
      filter_keys: [:password, :credit_card],
      filter_disable_url: false,
      filter_disable_params: false,
      filter_disable_session: false]
  end

  defp update_with_merged_config(config) do
    merged = Keyword.merge(default_config(), config)

    Enum.each(merged, fn {key, value} ->
      Application.put_env(:honeybadger, key, value)
    end)

    merged
  end

  defp verify_environment_name!(config) do
    case Keyword.get(config, :environment_name) do
      nil -> raise MissingEnvironmentNameError
      _ -> config
    end
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
