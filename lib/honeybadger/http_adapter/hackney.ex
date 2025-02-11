defmodule Honeybadger.HTTPAdapter.Hackney do
  @moduledoc """
  HTTP adapter module for making http requests with `:hackney`.

  You can also override the hackney options by updating the configuration:

      http_adapter: {Honeybadger.HTTPAdapter.Hackney, [...]}

  See `Honeybadger.HTTPAdapter` for more.
  """

  alias Honeybadger.{HTTPAdapter, HTTPAdapter.HTTPResponse}

  @behaviour HTTPAdapter

  @impl HTTPAdapter
  def request(method, url, body, headers, hackney_opts \\ nil) do
    raise_on_missing_hackney!()

    headers = headers ++ [HTTPAdapter.user_agent_header()]
    opts = hackney_opts || []

    body = binary_or_empty_binary(body)

    method
    |> :hackney.request(url, headers, body, opts)
    |> format_response()
  end

  defp format_response({:ok, status_code, headers, client_ref}) do
    {:ok, %HTTPResponse{status: status_code, headers: headers, body: body_from_ref(client_ref)}}
  end

  defp format_response({:error, error}), do: {:error, error}

  defp body_from_ref(ref) do
    ref
    |> :hackney.body()
    |> elem(1)
  end

  defp raise_on_missing_hackney! do
    Code.ensure_loaded?(:hackney) ||
      raise """
      #{inspect(__MODULE__)} requires `:hackney` to be included in your
      application.

      Please add it to your dependencies:

          {:hackney, "~> 1.1"}
      """
  end

  defp binary_or_empty_binary(nil), do: ""
  defp binary_or_empty_binary(str), do: str
end
