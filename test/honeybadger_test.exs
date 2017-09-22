defmodule HoneybadgerTest do
  use ExUnit.Case
  require Honeybadger

  setup do
    before = Application.get_env :honeybadger, :api_key

    Application.put_env :honeybadger, :api_key, "at3stk3y"

    on_exit(fn ->
      Application.put_env :honeybadger, :api_key, before
    end)
  end

  test "sending a notice on an active environment" do
    Application.put_env(:honeybadger, :exclude_envs, [])

    url = Application.get_env(:honeybadger, :origin) <> "/v1/notices"
    headers = [
      {"X-API-Key", "at3stk3y"},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
    ]

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

    {:ok, :unsent} = InactiveSample.notify
  end

  test "fetching application values" do
    on_exit(fn ->
      Application.delete_env(:honeybadger, :unused)
    end)

    Application.put_env(:honeybadger, :unused, "VALUE")

    assert Honeybadger.get_env(:unused) == "VALUE"
  end

  test "fetching system values" do
    on_exit(fn ->
      Application.delete_env(:honeybadger, :unused)
      System.delete_env("UNUSED")
    end)

    Application.put_env(:honeybadger, :unused, {:system, "UNUSED"})
    System.put_env("UNUSED", "VALUE")

    assert Honeybadger.get_env(:unused) == "VALUE"
  end

  test "an error is raised with unknown config keys" do
    assert_raise ArgumentError, ~r/parameter :unused is not set/, fn ->
      Honeybadger.get_env(:unused)
    end
  end

  test "an error is raised with an unset system env" do
    on_exit(fn ->
      Application.delete_env(:honeybadger, :unused)
    end)

    Application.put_env(:honeybadger, :unused, {:system, "UNUSED"})

    assert_raise ArgumentError, ~r/variable "UNUSED" is not set/, fn ->
      Honeybadger.get_env(:unused)
    end
  end

  test "getting and setting the context" do
    assert %{} == Honeybadger.context()

    Honeybadger.context(user_id: 1)
    assert %{user_id: 1} == Honeybadger.context()

    Honeybadger.context(%{user_id: 2})
    assert %{user_id: 2} == Honeybadger.context()
  end
end
