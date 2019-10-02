defmodule Honeybadger.PlugTest do
  use Honeybadger.Case
  use Plug.Test

  alias Plug.Conn.WrapperError

  defmodule CustomNotFound do
    defexception [:message]
  end

  defimpl Plug.Exception, for: CustomNotFound do
    def status(_), do: 404
  end

  defmodule PlugApp do
    use Plug.Router
    use Honeybadger.Plug

    alias Honeybadger.PlugTest.CustomNotFound

    plug(:match)
    plug(:dispatch)

    get "/bang" do
      _ = conn
      raise RuntimeError, "Oops"
    end

    get "/404_exception" do
      _ = conn
      raise CustomNotFound, "Oops"
    end
  end

  describe "handle_errors/2" do
    setup do
      {:ok, _} = Honeybadger.API.start(self())

      on_exit(&Honeybadger.API.stop/0)

      restart_with_config(exclude_envs: [], breadcrumbs_enabled: true)
    end

    test "errors are reported" do
      conn = conn(:get, "/bang")

      assert %WrapperError{reason: reason} = catch_error(PlugApp.call(conn, []))
      assert %RuntimeError{message: "Oops"} = reason

      assert_receive {:api_request, %{"breadcrumbs" => breadcrumbs}}

      assert List.first(breadcrumbs["trail"])["metadata"]["message"] == "Oops"
    end

    test "not found errors for plug are ignored" do
      conn = conn(:get, "/not_found")

      assert :function_clause == catch_error(PlugApp.call(conn, []))

      refute_receive {:api_request, _}
    end

    test "exceptions that implement Plug.Exception and return a 404 are ignored" do
      conn = conn(:get, "/404_exception")

      assert %WrapperError{reason: reason} = catch_error(PlugApp.call(conn, []))
      assert %CustomNotFound{message: "Oops"} = reason

      refute_receive {:api_request, _}
    end
  end
end
