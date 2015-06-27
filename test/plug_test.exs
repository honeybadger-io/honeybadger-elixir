defmodule Honeybadger.PlugTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  defmodule PlugApp do
    import Plug.Conn
    use Plug.Router
    use Honeybadger.Plug

    plug :match
    plug :dispatch

    get "/bang" do
      raise RuntimeError, "Oops"
    end
  end

  test "exception in a plug pipeline notifies Honeybadger" do
    with_mock Honeybadger, [notify: fn(_exception, _data) -> :ok end] do
      exception = %RuntimeError{message: "Oops"}
      conn = conn(:get, "/bang")

      assert exception == catch_error(PlugApp.call conn, [])
      assert called Honeybadger.notify(exception, :_)
    end
  end
end
