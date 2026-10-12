defmodule Honeybadger.ProxyTest do
  use Honeybadger.Case

  setup do
    test = self()

    TestServer.add("/v1/notices",
      via: :post,
      to: fn conn ->
        send(test, {:received, conn.host, Plug.Conn.get_req_header(conn, "proxy-authorization")})
        Plug.Conn.send_resp(conn, 201, "{}")
      end
    )

    :ok
  end

  test "sends through the configured proxy with the hackney adapter" do
    restart_with_config(
      exclude_envs: [],
      # Can't resolve, so the notice only arrives if it goes through the proxy
      origin: "http://honeybadger.invalid",
      http_adapter: Honeybadger.HTTPAdapter.Hackney,
      proxy: TestServer.url(),
      proxy_auth: {"user", "pass"}
    )

    Honeybadger.notify("proxy test")

    assert_receive {:received, "honeybadger.invalid", ["Basic " <> credentials]}
    assert Base.decode64!(credentials) == "user:pass"
  end

  test "ignores proxy config with the Req adapter" do
    restart_with_config(
      exclude_envs: [],
      origin: TestServer.url(),
      http_adapter: Honeybadger.HTTPAdapter.Req,
      proxy: "http://proxy.invalid:8080",
      proxy_auth: {"user", "pass"}
    )

    Honeybadger.notify("proxy test")

    assert_receive {:received, _host, []}
  end
end
