defmodule Honeybadger do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON

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
