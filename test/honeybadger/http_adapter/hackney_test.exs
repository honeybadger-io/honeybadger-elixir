defmodule Honeybadger.HTTPAdapter.HackneyTest do
  use Honeybadger.Case
  doctest Honeybadger.HTTPAdapter.Hackney

  alias Honeybadger.HTTPAdapter.{Hackney, HTTPResponse}

  describe "request/4" do
    test "handles unreachable host" do
      TestServer.start()
      url = TestServer.url()
      TestServer.stop()

      assert {:error, :econnrefused} = Hackney.request(:get, url, nil, [])
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
               Hackney.request(:get, TestServer.url("/get?a=1"), nil, [])
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
               Hackney.request(:post, TestServer.url("/post"), "a=1&b=2", [
                 {"content-type", "application/x-www-form-urlencoded"}
               ])
    end
  end

  @body %{"a" => "1", "b" => "2"}
  @headers [{"content-type", "application/json"}]
  @json_library (Code.ensure_loaded?(JSON) && JSON) || Jason
  @json_encoded_body @json_library.encode!(@body)
  @uri_encoded_body URI.encode_query(@body)

  test "decode_response_body/2" do
    assert {:ok, response} =
             Hackney.decode_response_body(
               %HTTPResponse{body: @json_encoded_body, headers: @headers},
               []
             )

    assert response.body == @body

    assert {:ok, response} =
             Hackney.decode_response_body(
               %HTTPResponse{
                 body: @json_encoded_body,
                 headers: [{"content-type", "application/json; charset=utf-8"}]
               },
               []
             )

    assert response.body == @body

    assert {:ok, response} =
             Hackney.decode_response_body(
               %HTTPResponse{
                 body: @json_encoded_body,
                 headers: [{"Content-Type", "application/json"}]
               },
               []
             )

    assert response.body == @body

    assert {:ok, response} =
             Hackney.decode_response_body(
               %HTTPResponse{
                 body: @json_encoded_body,
                 headers: [{"content-type", "text/javascript"}]
               },
               []
             )

    assert response.body == @body

    assert {:ok, response} =
             Hackney.decode_response_body(
               %HTTPResponse{
                 body: @uri_encoded_body,
                 headers: [{"content-type", "application/x-www-form-urlencoded"}]
               },
               []
             )

    assert response.body == @body

    assert {:ok, response} =
             Hackney.decode_response_body(%HTTPResponse{body: @body, headers: []}, [])

    assert response.body == @body

    assert {:error, %Honeybadger.InvalidResponseError{} = error} =
             Hackney.decode_response_body(%HTTPResponse{body: "%", headers: @headers}, [])

    assert error.response.body == "%"
  end
end
