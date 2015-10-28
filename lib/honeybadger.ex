defmodule Honeybadger do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON

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
          app: :my_app_name,
          exclude_envs: [:dev, :test],
          hostname: "myserver.domain.com",
          origin: "https://api.honeybadger.io",
          project_root: "/home/skynet",
          use_logger: true

    ### Notifying
    Honeybadger.notify is a macro so that it can be wiped away in environments
    that you don't need error tracking in such as dev and test. If you use the
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
    To use the logger all you need to do is set the `use_logger` configuration
    option to true. This will automatically receive any error reports for SASL
    compliant processes such as GenServers, GenEvents, Agents, Tasks and any
    process spawned using `proc_lib`.
  """

  @context :honeybadger_context

  @doc """
    This is here as a callback to Application to configure and start the
    Honeybadger client's dependencies. You'll likely never need to call this
    function yourself.
  """
  def start(_type, _opts) do
    app_config = Application.get_all_env(:honeybadger)
    config = Keyword.merge(default_config, app_config)

    Enum.map config, fn({key, value}) ->
      Application.put_env(:honeybadger, key, value)
    end

    if config[:use_logger] do
      :error_logger.add_report_handler(Honeybadger.Logger)
    end

    {Application.ensure_started(:httpoison), self}
  end

  defmacro notify(exception) do
    macro_notify(exception, {:%{}, [], []}, [])
  end

  defmacro notify(exception, context) do
    macro_notify(exception, context, [])
  end

  defmacro notify(exception, context, stacktrace) do
    macro_notify(exception, context, stacktrace)
  end

  defp macro_notify(exception, context, stacktrace) do
    exclude_envs = Application.get_env(:honeybadger, :exclude_envs, [:dev, :test])

    case Application.get_env(:honeybadger, :environment_name) in exclude_envs do
      false ->
        quote do
          Task.start fn ->
            Honeybadger.do_notify(unquote(exception), unquote(context), unquote(stacktrace))
          end
        end
      _ ->
        :ok
    end
  end

  def do_notify(exception, context, stacktrace) do
    if Enum.count(stacktrace) == 0 do
      {:current_stacktrace, stacktrace} = Process.info(self, :current_stacktrace)
    end

    backtrace = Backtrace.from_stacktrace(stacktrace)
    notice = Notice.new(exception, context, backtrace)
    {:ok, body} = JSON.encode(notice)

    api_url = Application.get_env(:honeybadger, :origin) <> "/v1/notices"
    api_key = Application.get_env(:honeybadger, :api_key)
    headers = [{"Accept", "application/json"},
               {"Content-Type", "application/json"},
               {"X-API-Key", api_key}]

    HTTP.post(api_url, body, headers)
  end

  def context do
    (Process.get(@context) || %{}) |> Enum.into(Map.new)
  end

  def context(dict) do
    Process.put(@context, Dict.merge(context, dict))
    context
  end

  defp default_config do
     [api_key: System.get_env("HONEYBADGER_API_KEY"),
      exclude_envs: [:dev, :test],
      hostname: :inet.gethostname |> elem(1) |> List.to_string,
      origin: "https://api.honeybadger.io",
      project_root: System.cwd,
      use_logger: true,
      environment_name: nil]
  end
end
