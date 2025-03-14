defmodule Honeybadger.HTTPAdapter.Req do
  @moduledoc """
  HTTP adapter module for making http requests with Req.

  You can also override the Req options by updating the configuration:

      http_adapter: {Honeybadger.HTTPAdapter.Req, [...]}

  See `Honeybadger.HTTPAdapter` for more.
  """
  alias Honeybadger.{HTTPAdapter, HTTPAdapter.HTTPResponse}

  @behaviour HTTPAdapter

  @impl HTTPAdapter
  def request(method, url, body, headers, opts \\ []) do
    opts =
      Keyword.merge(
        [
          method: method,
          url: url,
          headers: headers,
          body: body
        ],
        opts || []
      )

    req = apply(Req, :new, [opts])

    apply(Req, :request, [req])
    |> case do
      {:ok, response} ->
        {:ok,
         %HTTPResponse{status: response.status, headers: response.headers, body: response.body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl HTTPAdapter
  def decode_response_body(response, _opts) do
    {:ok, response}
  end
end
