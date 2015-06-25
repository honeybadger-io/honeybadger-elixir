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

  test "asdf" do
    with_mock Honeybadger, [notify: fn(_exception, _data) -> :ok end] do
      exception = %RuntimeError{message: "Oops"}
      metadata = %{}

      conn = conn(:get, "/bang")
      PlugApp.call conn, []

      assert called Honeybadger.notify(exception, metadata)
    end
  end
end
