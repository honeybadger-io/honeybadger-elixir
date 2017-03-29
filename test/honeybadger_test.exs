defmodule HoneybadgerTest do
  use ExUnit.Case
  alias HTTPoison, as: HTTP
  require Honeybadger

  @test_headers [
    {"X-API-Key", "at3stk3y"},
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  setup do
    before = Application.get_env :honeybadger, :api_key

    Application.put_env :honeybadger, :api_key, "at3stk3y"

    on_exit(fn ->
      Application.put_env :honeybadger, :api_key, before
    end)

    :meck.expect(HTTP, :post, fn(_url, _data, _headers) -> %HTTP.Response{} end)

    on_exit(fn ->
      :meck.unload(HTTP)
    end)
  end

  test "sending a notice on an active environment" do
    Application.put_env(:honeybadger, :exclude_envs, [])

    url = Application.get_env(:honeybadger, :origin) <> "/v1/notices"

    defmodule ActiveSample do
      def notify do
        Honeybadger.notify(%RuntimeError{}, %{})
      end
    end

    {:ok, _} = ActiveSample.notify
    :timer.sleep 250

    assert :meck.called(HTTP, :post, [url, :meck.is(fn(data) -> is_binary(data) end), headers])
  after
    Application.put_env(:honeybadger, :exclude_envs, [:dev, :test])
  end

  test "sending a notice on an inactive environment doesn't make an HTTP request" do
    assert [:dev, :test] == Application.get_env(:honeybadger, :exclude_envs)

    defmodule InactiveSample do
      def notify do
        Honeybadger.notify(%RuntimeError{}, %{})
      end
    end

    {:ok, _} = InactiveSample.notify
    :timer.sleep 250

    refute :meck.called(HTTP, :post, [:_, :_, :_])
  end

  test "getting and setting the context" do
    assert %{} == Honeybadger.context()

    Honeybadger.context(user_id: 1)
    assert %{user_id: 1} == Honeybadger.context()

    Honeybadger.context(%{user_id: 2})
    assert %{user_id: 2} == Honeybadger.context()
  end

end
