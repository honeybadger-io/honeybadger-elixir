defmodule Honeybadger do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON

  @api_key Application.get_env(:honeybadger, :api_key)
  @api_origin Application.get_env(:honeybadger, :origin)
  @api_url Enum.join([@api_origin, "/v1/notices"])
  @headers [{"Accept", "application/json"},
            {"Content-Type", "application/json"},
            {"X-API-Key", @api_key}]

  def notify(exception, metadata \\ %{}, stacktrace \\ System.stacktrace) do
    backtrace = Backtrace.from_stacktrace stacktrace
    {:ok, body} = JSON.encode Notice.new(exception, backtrace, metadata)

    HTTP.post @api_url, body, @headers

    :ok
  end
end
