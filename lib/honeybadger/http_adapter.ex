defmodule Honeybadger.HTTPAdapter do
  @moduledoc """
  HTTP adapter helper module.

  You can configure the HTTP adapter that Honeybadger uses by setting the
  following option:

      http_adapter: Honeybadger.HTTPAdapter.Req

  Default options can be set by passing a list of options:

      http_adapter: {Honeybadger.HTTPAdapter.Req, [...]}

  You can also set the client for the application:

      config :honeybadger, :http_adapter, Honeybadger.HTTPAdapter.Req

  ## Usage
      defmodule MyApp.MyHTTPAdapter do
        @behaviour Honeybadger.HTTPAdapter

        @impl true
        def request(method, url, body, headers, opts) do
          # ...
        end

        @impl true
        def decode_response_body(response, opts) do
          # ...
        end
      end
  """

  alias Honeybadger.{InvalidResponseError, ServerUnreachableError}

  defmodule HTTPResponse do
    @moduledoc """
    Struct used by HTTP adapters to normalize HTTP responses.
    """

    @type header :: {binary(), binary()}
    @type t :: %__MODULE__{
            http_adapter: atom(),
            request_url: binary(),
            status: integer(),
            headers: [header()],
            body: binary() | term()
          }

    defstruct http_adapter: nil, request_url: nil, status: 200, headers: [], body: ""

    def format(response) do
      [request_url | _rest] = String.split(response.request_url, "?", parts: 2)

      """
      HTTP Adapter: #{inspect(response.http_adapter)}
      Request URL: #{request_url}

      Response status: #{response.status}

      Response headers:
      #{Enum.map_join(response.headers, "\n", fn {key, val} -> "#{key}: #{val}" end)}

      Response body:
      #{inspect(response.body)}
      """
    end
  end

  @type method :: :get | :post
  @type body :: binary() | nil
  @type headers :: [{binary(), binary()}]

  @callback request(method(), binary(), body(), headers(), Keyword.t()) ::
              {:ok, map()} | {:error, any()}

  @callback decode_response_body(HTTPResponse.t(), Keyword.t()) ::
              {:ok, HTTPResponse.t()} | {:error, InvalidResponseError.t()}

  @doc """
  Sets a user agent header.

  The header value will be `Honeybadger-VERSION` with VERSION being the `:vsn` of
  `:honeybadger` app.
  """
  @spec user_agent_header() :: {binary(), binary()}
  def user_agent_header do
    version = Application.spec(:honeybadger, :vsn)

    {"User-Agent", "Honeybadger-#{version}"}
  end

  @default_http_client Enum.find_value(
                         [
                           {Req, Honeybadger.HTTPAdapter.Req},
                           {:hackney, Honeybadger.HTTPAdapter.Hackney}
                         ],
                         fn {dep, module} ->
                           Code.ensure_loaded?(dep) && {module, []}
                         end
                       )

  @doc """
  Makes an HTTP request.

  ## Options

  - `:http_adapter` - The HTTP adapter to use, defaults to
    `#{inspect(elem(@default_http_client, 0))}`
  """
  @spec request(atom(), binary(), binary() | nil, list(), Keyword.t()) ::
          {:ok, HTTPResponse.t()} | {:error, HTTPResponse.t()} | {:error, term()}
  def request(method, url, body, headers, opts) do
    {http_adapter, http_adapter_opts} = get_adapter(opts)

    with {:ok, response} <- http_adapter.request(method, url, body, headers, http_adapter_opts),
         {:ok, decoded_response} <- http_adapter.decode_response_body(response, opts) do
      {request_result(decoded_response),
       %{decoded_response | http_adapter: http_adapter, request_url: url}}
    else
      {:error, %Honeybadger.InvalidResponseError{} = error} ->
        {:error, error}

      {:error, error} ->
        {:error,
         ServerUnreachableError.exception(
           reason: error,
           http_adapter: http_adapter,
           request_url: url
         )}
    end
  end

  defp get_adapter(opts) do
    default_http_adapter = Application.get_env(:honeybadger, :http_adapter, @default_http_client)

    case Keyword.get(opts, :http_adapter, default_http_adapter) do
      {http_adapter, opts} -> {http_adapter, opts}
      http_adapter when is_atom(http_adapter) -> {http_adapter, nil}
    end
  end

  defp request_result(%{status: status}) when status in 200..399, do: :ok
  defp request_result(%{status: status}) when status in 400..599, do: :error
end
