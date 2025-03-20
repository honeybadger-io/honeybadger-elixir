defmodule Honeybadger.InvalidResponseError do
  defexception [:response]

  alias Honeybadger.HTTPAdapter.HTTPResponse

  @type t :: %__MODULE__{
          response: HTTPResponse.t()
        }

  def message(exception) do
    """
    An invalid response was received.

    #{HTTPResponse.format(exception.response)}
    """
  end
end
