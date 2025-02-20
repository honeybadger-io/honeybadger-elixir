defmodule Honeybadger.HTTPAdapterTest do
  use Honeybadger.Case
  # doctest Honeybadger.Strategy

  alias Honeybadger.{HTTPAdapter, HTTPAdapter.HTTPResponse, InvalidResponseError}

  defmodule HTTPMock do
    @json_library (Code.ensure_loaded?(JSON) && JSON) || Jason

    def request(:get, "http-adapter", nil, [], nil) do
      {:ok, %HTTPResponse{status: 200, headers: [], body: nil}}
    end

    def request(:get, "http-adapter-with-opts", nil, [], opts) do
      {:ok, %HTTPResponse{status: 200, headers: [], body: opts}}
    end

    def request(:get, "json-encoded-body", nil, [], nil) do
      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: @json_library.encode!(%{"a" => 1})
       }}
    end

    def request(:get, "json-encoded-body-already-decoded", nil, [], nil) do
      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: %{"a" => 1}
       }}
    end

    def request(:get, "json-encoded-body-text/javascript-header", nil, [], nil) do
      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "text/javascript"}],
         body: @json_library.encode!(%{"a" => 1})
       }}
    end

    def request(:get, "invalid-json-body", nil, [], nil) do
      {:ok,
       %HTTPResponse{status: 200, headers: [{"content-type", "application/json"}], body: "%"}}
    end

    def request(:get, "json-no-headers", nil, [], nil) do
      {:ok, %HTTPResponse{status: 200, headers: [], body: @json_library.encode!(%{"a" => 1})}}
    end

    def request(:get, "form-data-body", nil, [], nil) do
      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "application/x-www-form-urlencoded"}],
         body: URI.encode_query(%{"a" => 1})
       }}
    end

    def request(:get, "form-data-body-already-decoded", nil, [], nil) do
      {:ok,
       %HTTPResponse{
         status: 200,
         headers: [{"content-type", "application/x-www-form-urlencoded"}],
         body: %{"a" => 1}
       }}
    end

    def decode_response_body(response, opts) do
      case decode(response.headers, response.body, opts) do
        {:ok, body} -> {:ok, %{response | body: body}}
        {:error, _error} -> {:error, InvalidResponseError.exception(response: response)}
      end
    end

    defp decode(headers, body, opts) when is_binary(body) do
      case List.keyfind(headers, "content-type", 0) do
        {"content-type", "application/json" <> _rest} ->
          Jason.decode(body, opts)

        {"content-type", "text/javascript" <> _rest} ->
          Jason.decode(body, opts)

        {"content-type", "application/x-www-form-urlencoded" <> _rest} ->
          {:ok, URI.decode_query(body)}

        _any ->
          {:ok, body}
      end
    end

    defp decode(_headers, body, _opts), do: {:ok, body}
  end

  test "request/5" do
    assert HTTPAdapter.request(:get, "http-adapter", nil, [], http_adapter: HTTPMock) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [],
                body: nil,
                http_adapter: HTTPMock,
                request_url: "http-adapter"
              }}

    assert HTTPAdapter.request(:get, "http-adapter-with-opts", nil, [],
             http_adapter: {HTTPMock, a: 1}
           ) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [],
                body: [a: 1],
                http_adapter: HTTPMock,
                request_url: "http-adapter-with-opts"
              }}

    assert HTTPAdapter.request(:get, "json-encoded-body", nil, [], http_adapter: HTTPMock) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [{"content-type", "application/json"}],
                body: %{"a" => 1},
                http_adapter: HTTPMock,
                request_url: "json-encoded-body"
              }}

    assert HTTPAdapter.request(:get, "json-encoded-body-already-decoded", nil, [],
             http_adapter: HTTPMock
           ) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [{"content-type", "application/json"}],
                body: %{"a" => 1},
                http_adapter: HTTPMock,
                request_url: "json-encoded-body-already-decoded"
              }}

    assert HTTPAdapter.request(:get, "json-encoded-body-text/javascript-header", nil, [],
             http_adapter: HTTPMock
           ) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [{"content-type", "text/javascript"}],
                body: %{"a" => 1},
                http_adapter: HTTPMock,
                request_url: "json-encoded-body-text/javascript-header"
              }}

    assert {:error, %InvalidResponseError{}} =
             HTTPAdapter.request(:get, "invalid-json-body", nil, [], http_adapter: HTTPMock)

    assert HTTPAdapter.request(:get, "json-no-headers", nil, [], http_adapter: HTTPMock) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [],
                body: Jason.encode!(%{"a" => 1}),
                http_adapter: HTTPMock,
                request_url: "json-no-headers"
              }}

    assert HTTPAdapter.request(:get, "form-data-body", nil, [], http_adapter: HTTPMock) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [{"content-type", "application/x-www-form-urlencoded"}],
                body: %{"a" => "1"},
                http_adapter: HTTPMock,
                request_url: "form-data-body"
              }}

    assert HTTPAdapter.request(:get, "form-data-body-already-decoded", nil, [],
             http_adapter: HTTPMock
           ) ==
             {:ok,
              %HTTPResponse{
                status: 200,
                headers: [{"content-type", "application/x-www-form-urlencoded"}],
                body: %{"a" => 1},
                http_adapter: HTTPMock,
                request_url: "form-data-body-already-decoded"
              }}
  end
end
