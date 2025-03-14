defmodule Honeybadger.HTTPAdapter.ReqTest do
  use Honeybadger.Case
  doctest Honeybadger.HTTPAdapter.Req

  alias Req.TransportError
  alias Honeybadger.HTTPAdapter.{HTTPResponse, Req}

  # Test retries quickly
  @req_opts [retry_delay: 0]

  describe "request/4" do
    test "handles unreachable host" do
      TestServer.start()
      url = TestServer.url()
      TestServer.stop()

      assert {:error, %TransportError{reason: :econnrefused}} =
               Req.request(:get, url, nil, [], retry: false)
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
               Req.request(:get, TestServer.url("/get?a=1"), nil, [], @req_opts)
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

          Plug.Conn.send_resp(conn, 200, "")
        end
      )

      assert {:ok, %HTTPResponse{status: 200}} =
               Req.request(
                 :post,
                 TestServer.url("/post"),
                 "a=1&b=2",
                 [
                   {"content-type", "application/x-www-form-urlencoded"}
                 ],
                 @req_opts
               )
    end
  end
end
