defmodule HoneybadgerTest do
  use ExUnit.Case
  alias HTTPoison, as: HTTP
  alias Poison, as: JSON
  alias Honeybadger.Notice
  import Mock

  test "sending a notice" do
    with_mock HTTP, [post: fn(_url, _data, _headers) -> %HTTP.Response{} end] do
      exception = %RuntimeError{message: "Oops"}
      url = Application.get_env(:honeybadger, :endpoint) <> "/v1/notices"
      body = JSON.encode! Notice.new(exception, [])
      headers = [{"Accept", "application/json"},
                 {"Content-Type", "application/json"},
                 {"X-API-Key", "at3stk3y"}]


      Honeybadger.notify exception

      assert called HTTP.post(url, body, headers)
    end
  end
end
