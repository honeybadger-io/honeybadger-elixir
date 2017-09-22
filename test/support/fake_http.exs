defmodule FakeHttp do
  @moduledoc false

  @doc false
  def post(_url, headers, body, _options) do
    {:ok, 201, headers, body}
  end
end
