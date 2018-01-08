defmodule Honeybadger.PlugTest do
  use Honeybadger.Case
  use Plug.Test

  defmodule PlugApp do
    use Plug.Router
    use Honeybadger.Plug

    plug(:match)
    plug(:dispatch)

    get "/bang" do
      _ = conn
      raise RuntimeError, "Oops"
    end
  end

  describe "handle_errors/2" do
    setup do
      {:ok, _} = Honeybadger.API.start(self())

      on_exit(&Honeybadger.API.stop/0)

      restart_with_config(exclude_envs: [])
    end

    test "errors are reported" do
      conn = conn(:get, "/bang")

      assert %RuntimeError{} = catch_error(PlugApp.call(conn, []))

      assert_receive {:api_request, _}
    end

    test "not found errors for plug are ignored" do
      conn = conn(:get, "/not_found")

      assert :function_clause == catch_error(PlugApp.call(conn, []))

      refute_receive {:api_request, _}
    end
  end
end
