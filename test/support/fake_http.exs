defmodule FakeHttp do
  alias Poison, as: JSON

  def post(url, body, headers) do
    body = JSON.decode!(body)

    %{"url" => url,
      "body" => body,
      "headers" => headers}
  end
end
