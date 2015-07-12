defmodule HoneybadgerTest do
  use ExUnit.Case
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON
  alias Honeybadger.Notice
  import Mock

  setup do
    before = Application.get_env :honeybadger, :api_key

    Application.put_env :honeybadger, :api_key, "at3stk3y"

    on_exit(fn ->
      Application.put_env :honeybadger, :api_key, before
    end)
  end

  test "sending a notice" do
    with_mock HTTP, [post: fn(_url, _data, _headers) -> %HTTP.Response{} end] do
      exception = %RuntimeError{message: "Oops"}
      url = Application.get_env(:honeybadger, :origin) <> "/v1/notices"
      body = JSON.encode! Notice.new(exception, [])
      headers = [{"Accept", "application/json"},
                 {"Content-Type", "application/json"},
                 {"X-API-Key", "at3stk3y"}]

      Honeybadger.notify exception

      assert called HTTP.post(url, body, headers)
    end
  end
end
