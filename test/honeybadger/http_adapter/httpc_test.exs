defmodule Honeybadger.HTTPAdapter.HttpcTest do
  use Honeybadger.Case
  doctest Honeybadger.HTTPAdapter.Httpc

  alias Honeybadger.HTTPAdapter.{Httpc, HTTPResponse}

  describe "request/4" do
    test "handles SSL" do
      TestServer.start(scheme: :https)
      TestServer.add("/", via: :get)

      assert {:ok, %HTTPResponse{status: 200, body: "HTTP/1.1"}} =
               Httpc.request(:get, TestServer.url(), nil, [],
                 ssl: [cacerts: TestServer.x509_suite().cacerts]
               )

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/cacerts.pem",
        :public_key.pem_encode(
          Enum.map(TestServer.x509_suite().cacerts, &{:Certificate, &1, :not_encrypted})
        )
      )

      TestServer.add("/", via: :get)

      assert {:ok, %HTTPResponse{status: 200, body: "HTTP/1.1"}} =
               Httpc.request(:get, TestServer.url(), nil, [],
                 ssl: [cacertfile: ~c"tmp/cacerts.pem"]
               )
    end

    test "handles SSL with bad certificate" do
      TestServer.start(scheme: :https)

      bad_host_url = TestServer.url(host: "bad-host.localhost")
      httpc_opts = [ssl: [cacerts: TestServer.x509_suite().cacerts]]

      assert {:error, {:failed_connect, error}} =
               Httpc.request(:get, bad_host_url, nil, [], httpc_opts)

      assert {:tls_alert, {:handshake_failure, _error}} = inet_error(error)
    end

    test "handles SSL with bad certificate and no verification" do
      TestServer.start(scheme: :https)
      TestServer.add("/", via: :get)

      bad_host_url = TestServer.url(host: "bad-host.localhost")

      httpc_opts = [
        ssl: [
          cacerts: TestServer.x509_suite().cacerts,
          verify: :verify_none,
          verify_fun: {fn _cert, _event, state -> {:valid, state} end, nil}
        ]
      ]

      assert {:ok, %HTTPResponse{status: 200}} =
               Httpc.request(:get, bad_host_url, nil, [], httpc_opts)
    end

    test "handles unreachable host" do
      TestServer.start()
      url = TestServer.url()
      TestServer.stop()

      assert {:error, {:failed_connect, error}} = Httpc.request(:get, url, nil, [])
      assert inet_error(error) == :econnrefused
    end

    test "handles query in URL" do
      TestServer.add("/get",
        via: :get,
        to: fn conn ->
          assert conn.query_string == "a=1"

          Plug.Conn.send_resp(conn, 200, "")
        end
      )

      assert {:ok, %HTTPResponse{status: 200}} =
               Httpc.request(:get, TestServer.url("/get?a=1"), nil, [])
    end

    test "handles POST" do
      TestServer.add("/post",
        via: :post,
        to: fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn, [])
          params = URI.decode_query(body)

          assert params["a"] == "1"
          assert params["b"] == "2"

          assert Plug.Conn.get_req_header(conn, "content-type") == [
                   "application/x-www-form-urlencoded"
                 ]

          assert Plug.Conn.get_req_header(conn, "content-length") == ["7"]

          Plug.Conn.send_resp(conn, 200, "")
        end
      )

      assert {:ok, %HTTPResponse{status: 200}} =
               Httpc.request(:post, TestServer.url("/post"), "a=1&b=2", [
                 {"content-type", "application/x-www-form-urlencoded"}
               ])
    end
  end

  defp inet_error([_, {:inet, [:inet], error}]), do: error
end
