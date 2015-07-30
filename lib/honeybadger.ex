defmodule Honeybadger do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON

  @context :honeybadger_context

  @doc """
    This is here as a callback to Application to configure and start the Honeybadger client's dependencies. You'll likely never need to call this function yourself.
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
    
    case Mix.env in exclude_envs do
      false ->
        quote do
          Honeybadger.do_notify(unquote(exception), unquote(context), unquote(stacktrace))
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
  end

  defp default_config do
     [api_key: System.get_env("HONEYBADGER_API_KEY"),
      exclude_envs: [:dev, :test],
      hostname: :inet.gethostname |> elem(1) |> List.to_string,
      origin: "https://api.honeybadger.io",
      project_root: System.cwd,
      use_logger: false]
  end
end
