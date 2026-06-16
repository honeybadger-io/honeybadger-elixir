defmodule Honeybadger.ServerUnreachableError do
  defexception [:http_adapter, :request_url, :reason]

  @type t :: %__MODULE__{
          http_adapter: module(),
          request_url: binary(),
          reason: term()
        }

  def message(exception) do
    [url | _rest] = String.split(exception.request_url, "?", parts: 2)

    """
    The server was unreachable.

    HTTP Adapter: #{inspect(exception.http_adapter)}
    Request URL: #{url}

    Reason:
    #{inspect(exception.reason)}
    """
  end
end
