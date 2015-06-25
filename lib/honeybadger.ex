defmodule Honeybadger do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON

  @api_url Application.get_env(:honeybadger, :endpoint) <> "/v1/notices"
  @api_key Application.get_env(:honeybadger, :api_key)
  @headers [{"Accept", "application/json"},
            {"Content-Type", "application/json"},
            {"X-API-Key", @api_key}]

  def notify(exception, metadata \\ %{}) do
    backtrace = Backtrace.from_stacktrace System.stacktrace
    {:ok, body} = JSON.encode Notice.new(exception, backtrace, metadata)

    HTTP.post @api_url, body, @headers

    :ok
  end
end
