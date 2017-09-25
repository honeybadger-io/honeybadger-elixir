defmodule HoneybadgerTest do
  use Honeybadger.Case

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    on_exit(&Honeybadger.API.stop/0)
  end

  test "sending a notice on an active environment" do
    restart_with_config(exclude_envs: [])

    :ok = Honeybadger.notify(%RuntimeError{}, %{})

    assert_receive {:api_request, _}
  end

  test "sending a notice on an inactive environment doesn't make an HTTP request" do
    restart_with_config(exclude_envs: [:dev, :test])

    :ok = Honeybadger.notify(%RuntimeError{}, %{})

    refute_receive {:api_request, _}
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
