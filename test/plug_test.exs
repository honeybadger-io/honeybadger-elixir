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
      _ = conn
      raise RuntimeError, "Oops"
    end
  end

  test "exception in a plug pipeline notifies Honeybadger" do
    with_mock Honeybadger, [notify: fn(_exception, _data, _stack) -> :ok end] do
      exception = %RuntimeError{message: "Oops"}
      conn = conn(:get, "/bang")

      assert exception == catch_error(PlugApp.call conn, [])
      assert called Honeybadger.notify(exception, :_, :_)
    end
  end

  test "exception on a non-existant route does not notify Honeybadger" do
    with_mock Honeybadger, [notify: fn(_exception, _data, _stack) -> :ok end] do
      conn = conn(:get, "/not_found")
      catch_error(PlugApp.call conn, [])

      refute called Honeybadger.notify
    end
  end
end
