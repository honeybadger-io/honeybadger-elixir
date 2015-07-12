defmodule Honeybadger do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON

  @doc """
    This is here as a callback to Application to configure and start the Honeybadger client's dependencies. You'll likely never need to call this function yourself.
  """
  def start(_type, _opts) do 
    defaults = [
      api_key: System.get_env("HONEYBADGER_API_KEY"),
      hostname: :inet.gethostname |> elem(1) |> List.to_string,
      origin: "https://api.honeybadger.io",
      project_root: System.cwd
    ]
    app_config = Application.get_all_env(:honeybadger)
    config = Keyword.merge(defaults, app_config)

    Enum.map config, fn({key, value}) ->
      Application.put_env(:honeybadger, key, value)
    end

    {Application.ensure_started(:httpoison), self}
  end

  def notify(exception, metadata \\ %{}, stacktrace \\ System.stacktrace) do
    backtrace = Backtrace.from_stacktrace stacktrace
    notice = Notice.new(exception, backtrace, metadata)
    {:ok, body} = JSON.encode notice

    HTTP.post api_url, body, headers

    :ok
  end

  defp api_url do
    Application.get_env(:honeybadger, :origin) <> "/v1/notices"
  end

  defp headers do
    api_key = Application.get_env(:honeybadger, :api_key)

    [{"Accept", "application/json"},
    {"Content-Type", "application/json"},
    {"X-API-Key", api_key}]
  end
end
