defmodule Honeybadger.PlugDataTest do
  use Honeybadger.Case, async: true
  use Plug.Test

  alias Honeybadger.PlugData

  describe "build_plug_env/2" do
    test "building outside of a phoenix app" do
      conn = conn(:get, "/bang?foo=bar")

      assert match?(
               %{component: "PlugApp", params: %{"foo" => "bar"}, url: "/bang"},
               PlugData.build_plug_env(conn, PlugApp)
             )
    end

    test "building inside of a phoenix app" do
      conn =
        :get
        |> conn("/bang")
        |> put_private(:phoenix_controller, DanController)
        |> put_private(:phoenix_action, :fight)

      assert match?(
               %{action: "fight", component: "DanController"},
               PlugData.build_plug_env(conn, PlugApp)
             )
    end
  end

  describe "build_cgi_data/1" do
    test "general CGI data is extracted" do
      conn = conn(:get, "/bang")
      %{port: remote_port} = get_peer_data(conn)

      cgi_data = %{
        "CONTENT_LENGTH" => [],
        "ORIGINAL_FULLPATH" => "/bang",
        "PATH_INFO" => "bang",
        "QUERY_STRING" => "",
        "REMOTE_ADDR" => "127.0.0.1",
        "REMOTE_PORT" => remote_port,
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME" => "",
        "SERVER_ADDR" => "127.0.0.1",
        "SERVER_NAME" => Application.get_env(:honeybadger, :hostname),
        "SERVER_PORT" => 80
      }

      assert cgi_data == PlugData.build_cgi_data(conn)
    end

    test "formatted headers are included" do
      headers = [
        {"content-type", "application/json"},
        {"origin", "somewhere"}
      ]

      conn = %{conn(:get, "/bang") | req_headers: headers}

      assert match?(
               %{"HTTP_CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => "somewhere"},
               PlugData.build_cgi_data(conn)
             )
    end
  end
end
