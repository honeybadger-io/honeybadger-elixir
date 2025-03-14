defmodule Honeybadger.HTTPAdapter.Hackney do
  @moduledoc """
  HTTP adapter module for making http requests with `:hackney`.

  You can also override the hackney options by updating the configuration:

      http_adapter: {Honeybadger.HTTPAdapter.Hackney, [...]}

  See `Honeybadger.HTTPAdapter` for more.
  """

  alias Honeybadger.{HTTPAdapter, HTTPAdapter.HTTPResponse}
  alias Honeybadger.InvalidResponseError

  @behaviour HTTPAdapter

  @impl HTTPAdapter
  def request(method, url, body, headers, hackney_opts \\ nil) do
    opts = hackney_opts || []

    body = binary_or_empty_binary(body)

    apply(:hackney, :request, [method, url, headers, body, opts])
    |> format_response()
  end

  @impl HTTPAdapter
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

  defp format_response({:ok, status_code, headers, client_ref}) do
    {:ok, %HTTPResponse{status: status_code, headers: headers, body: body_from_ref(client_ref)}}
  end

  defp format_response({:error, error}), do: {:error, error}

  defp body_from_ref(ref) do
    apply(:hackney, :body, [ref])
    |> elem(1)
  end

  defp binary_or_empty_binary(nil), do: ""
  defp binary_or_empty_binary(str), do: str
end
