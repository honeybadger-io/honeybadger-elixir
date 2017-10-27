defmodule Honeybadger.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

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

  test "exceptions on a non-existant route are ignored" do
    conn = conn(:get, "/not_found")

    # the way erlang errors are raised was changed in https://github.com/elixir-plug/plug/pull/518
    # Plug now sends an error which is not normalized, hence the change to the test
    assert :function_clause == catch_error(PlugApp.call conn, [])
  end

  test "build_plug_env/2" do
    conn = conn(:get, "/bang?foo=bar")
    plug_env = %{action: "",
                 cgi_data: Honeybadger.Plug.build_cgi_data(conn),
                 component: "Honeybadger.PlugTest.PlugApp",
                 params: %{"foo" => "bar"},
                 session: %{},
                 url: "/bang"}

    assert plug_env == Honeybadger.Plug.build_plug_env(conn, PlugApp)
  end

  test "build_plug_env/2 in phoenix" do
    conn = conn(:get, "/bang?foo=bar")
           |> put_private(:phoenix_controller, DanController)
           |> put_private(:phoenix_action, :fight)

    plug_env = %{action: "fight",
                 cgi_data: Honeybadger.Plug.build_cgi_data(conn),
                 component: "DanController",
                 params: %{"foo" => "bar"},
                 session: %{},
                 url: "/bang"}

    assert plug_env == Honeybadger.Plug.build_plug_env(conn, PlugApp, _phoenix = true)
  end

  test "build_cgi_data/1" do
    conn = conn(:get, "/bang")
    {_, remote_port} = conn.peer
    cgi_data = %{"CONTENT_LENGTH" => [],
                 "ORIGINAL_FULLPATH" => "/bang",
                 "PATH_INFO" => "bang",
                 "QUERY_STRING" => "",
                 "REMOTE_ADDR" => "127.0.0.1",
                 "REMOTE_PORT" => remote_port,
                 "REQUEST_METHOD" => "GET",
                 "SCRIPT_NAME" => "",
                 "SERVER_ADDR" => "127.0.0.1",
                 "SERVER_NAME" => Application.get_env(:honeybadger, :hostname),
                 "SERVER_PORT" => 80}

    assert cgi_data == Honeybadger.Plug.build_cgi_data(conn)
  end

  test "get_remote_addr/1" do
    assert "127.0.0.1" == Honeybadger.Plug.get_remote_addr({127, 0, 0, 1})
  end

  test "header_to_rack_format/2" do
    header = {"content-type", "application/json"}
    rack_format = %{"HTTP_CONTENT_TYPE" => "application/json"}

    assert rack_format == Honeybadger.Plug.header_to_rack_format(header, %{})
  end
end
