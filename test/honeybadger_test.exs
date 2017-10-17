defmodule HoneybadgerTest do
  use Honeybadger.Case

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    on_exit(&Honeybadger.API.stop/0)
  end

  test "sending a notice on an active environment" do
    restart_with_config(exclude_envs: [])

    logged = capture_log(fn ->
      :ok = Honeybadger.notify(%RuntimeError{})
    end)

    assert logged =~ ~s|[Honeybadger] API success: "{}"|

    assert_receive {:api_request, _}
  end

  test "sending a notice on an inactive environment doesn't make an HTTP request" do
    restart_with_config(exclude_envs: [:dev, :test])

    logged = capture_log(fn ->
      :ok = Honeybadger.notify(%RuntimeError{})
    end)

    refute logged =~ "[Honeybadger] API"

    refute_receive {:api_request, _}
  end

  test "sending a notice with exception stacktrace" do
    restart_with_config(exclude_envs: [])

    try do
      raise RuntimeError
    rescue
      exception ->
        :ok = Honeybadger.notify(exception)
    end

    assert_receive {:api_request, %{"error" => %{"backtrace" => backtrace}}}

    traced = for %{"file" => file, "method" => fun} <- backtrace, do: {file, fun}

    refute {"lib/process.ex", "info"} in traced
    refute {"lib/honeybadger.ex", "backtrace"} in traced
    refute {"lib/honeybadger.ex", "notify"} in traced
    assert {"test/honeybadger_test.exs",
            "test sending a notice with exception stacktrace"} in traced
  end

  test "fetching all application values" do
    on_exit(fn ->
      Application.delete_env(:honeybadger, :option_a)
      Application.delete_env(:honeybadger, :option_b)
      System.delete_env("OPTION_A")
    end)

    Application.put_env(:honeybadger, :option_a, {:system, "OPTION_A"})
    Application.put_env(:honeybadger, :option_b, :value)
    System.put_env("OPTION_A", "VALUE")

    all_env = Honeybadger.get_all_env()

    assert all_env[:option_a] == "VALUE"
    assert all_env[:option_b] == :value
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
