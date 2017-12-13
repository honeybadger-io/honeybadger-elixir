defmodule HoneybadgerTest do
  use Honeybadger.Case

  doctest Honeybadger

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    on_exit(&Honeybadger.API.stop/0)
  end

  test "sending a notice on an active environment" do
    restart_with_config(exclude_envs: [])

    logged = capture_log(fn ->
      :ok = Honeybadger.notify(%RuntimeError{})
      assert_receive {:api_request, _}
    end)

    assert logged =~ ~s|[Honeybadger] API success: "{}"|
  end

  test "warn if incomplete env" do
    logged = capture_log(fn ->
      restart_with_config(api_key: nil, environment_name: :test, exclude_envs: [])
    end)

    assert logged =~ ~s|mandatory :honeybadger config key api_key not set|
  end

  test "warn in an excluded env" do
    logged =
      capture_log(fn ->
        restart_with_config(environment_name: :test, exclude_envs: [:test])
      end)

    assert logged =~
             ~s|Development mode is enabled. Data will not be reported until you deploy your app.|
  end

  test "should not show warning if env is complete" do
    logged = capture_log(fn ->
      restart_with_config(api_key: "test", environment_name: :test, exclude_envs: [])
    end)

    refute logged =~ ~s|mandatory :honeybadger config key api_key not set|
  end

  test "sending a notice on an inactive environment doesn't make an HTTP request" do
    restart_with_config(exclude_envs: [:dev, :test])

    logged = capture_log(fn ->
      :ok = Honeybadger.notify(%RuntimeError{})
    end)

    refute logged =~ "[Honeybadger] API"

    refute_receive {:api_request, _}
  end

  test "sending a notice in an active environment without an API key doesn't make an HTTP request" do
    restart_with_config(exclude_envs: [], api_key: nil)

    logged = capture_log(fn ->
      :ok = Honeybadger.notify(%RuntimeError{})
      refute_receive {:api_request, _}
    end)

    refute logged =~ "[Honeybadger] API"
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

    refute {"lib/process.ex", "info/1"} in traced
    refute {"lib/honeybadger.ex", "backtrace/1"} in traced
    refute {"lib/honeybadger.ex", "notify/3"} in traced
    assert {"test/honeybadger_test.exs",
            "test sending a notice with exception stacktrace/1"} in traced
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

  test "an error is not raised with an unset system env" do
    on_exit(fn ->
      Application.delete_env(:honeybadger, :unused)
    end)

    Application.put_env(:honeybadger, :unused, {:system, "UNUSED"})

    assert Honeybadger.get_env(:unused) == nil
  end

  test "getting and setting the context" do
    assert %{} == Honeybadger.context()

    Honeybadger.context(user_id: 1)
    assert %{user_id: 1} == Honeybadger.context()

    Honeybadger.context(%{user_id: 2})
    assert %{user_id: 2} == Honeybadger.context()
  end
end
