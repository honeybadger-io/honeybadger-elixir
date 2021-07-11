defmodule HoneybadgerTest do
  use Honeybadger.Case

  doctest Honeybadger

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    on_exit(&Honeybadger.API.stop/0)
  end

  describe "deprecated Honeybadger.notify works" do
    test "sending a notice with exception stacktrace" do
      restart_with_config(exclude_envs: [])

      logged =
        capture_log(
          fn ->
            try do
              raise RuntimeError
            rescue
              exception ->
                :ok = Honeybadger.notify(exception, %{}, __STACKTRACE__)
            end
          end,
          :stderr
        )

      assert logged =~ ~s|Reporting with notify/3 is deprecated, use notify/2 instead|

      assert_receive {:api_request, %{"error" => %{"backtrace" => backtrace}}}

      traced = for %{"file" => file, "method" => fun} <- backtrace, do: {file, fun}

      refute {"lib/process.ex", "info/1"} in traced
      refute {"lib/honeybadger.ex", "backtrace/1"} in traced
      refute {"lib/honeybadger.ex", "notify/3"} in traced

      assert {"test/honeybadger_test.exs",
              "test deprecated Honeybadger.notify works sending a notice with exception stacktrace/1"} in traced
    end

    test "sending a notice includes extra information" do
      restart_with_config(exclude_envs: [])
      fun = fn :hi -> nil end

      logged =
        capture_log(
          fn ->
            try do
              fun.(:boom)
            rescue
              exception ->
                :ok = Honeybadger.notify(exception, %{}, __STACKTRACE__)
            end
          end,
          :stderr
        )

      assert logged =~ ~s|Reporting with notify/3 is deprecated, use notify/2 instead|

      assert_receive {:api_request, %{"error" => error}}
      assert error["class"] == "FunctionClauseError"
      assert String.contains?(error["message"], ":boom")
    end
  end

  describe "Honeybadger.notify" do
    test "sending a notice on an active environment" do
      restart_with_config(exclude_envs: [])

      logged =
        capture_log(fn ->
          :ok = Honeybadger.notify(%RuntimeError{})
          assert_receive {:api_request, _}
        end)

      assert logged =~ ~s|[Honeybadger] API success: "{}"|
    end

    test "sending a notice on an inactive environment doesn't make an HTTP request" do
      restart_with_config(exclude_envs: [:dev, :test])

      logged =
        capture_log(fn ->
          :ok = Honeybadger.notify(%RuntimeError{})
        end)

      refute logged =~ "[Honeybadger] API"

      refute_receive {:api_request, _}
    end

    test "sending a notice in an active environment without an API key doesn't make an HTTP request" do
      restart_with_config(exclude_envs: [], api_key: nil)

      logged =
        capture_log(fn ->
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
          :ok = Honeybadger.notify(exception, stacktrace: __STACKTRACE__)
      end

      assert_receive {:api_request, %{"error" => %{"backtrace" => backtrace}}}

      traced = for %{"file" => file, "method" => fun} <- backtrace, do: {file, fun}

      refute {"lib/process.ex", "info/1"} in traced
      refute {"lib/honeybadger.ex", "backtrace/1"} in traced
      refute {"lib/honeybadger.ex", "notify/3"} in traced

      assert {"test/honeybadger_test.exs",
              "test Honeybadger.notify sending a notice with exception stacktrace/1"} in traced
    end

    test "sending a notice includes extra information" do
      restart_with_config(exclude_envs: [])
      fun = fn :hi -> nil end

      try do
        fun.(:boom)
      rescue
        exception ->
          :ok = Honeybadger.notify(exception, stacktrace: __STACKTRACE__)
      end

      assert_receive {:api_request, %{"error" => error}}
      assert error["class"] == "FunctionClauseError"
      assert String.contains?(error["message"], ":boom")
    end

    test "sending a notice includes fingerprint" do
      restart_with_config(exclude_envs: [])

      Honeybadger.notify("Custom error", fingerprint: "fingerprint-xpto")

      assert_receive {:api_request, %{"error" => error}}
      assert error["fingerprint"] == "fingerprint-xpto"
    end

    test "sending a notice with custom class and message" do
      restart_with_config(exclude_envs: [])

      Honeybadger.notify(%{class: "CustomError", message: "a message"})

      assert_receive {:api_request, %{"error" => error}}
      assert "CustomError" = error["class"]
      assert "a message" = error["message"]
    end

    test "sending a notice when the message is an improper list of iodata" do
      restart_with_config(exclude_envs: [])

      message = ["RealError", 32, 40, "#PID<0.1.0>" | " ** Error"]

      Honeybadger.notify(%RuntimeError{message: message})

      assert_receive {:api_request, %{"error" => error}}
      assert error["message"] == "RealError (#PID<0.1.0> ** Error"
    end

    test "sending a notice when the message is nil" do
      restart_with_config(exclude_envs: [])

      Honeybadger.notify(%RuntimeError{message: nil})

      assert_receive {:api_request, %{"error" => error}}
      assert error["message"] == nil
    end
  end

  test "warn if incomplete env" do
    logged =
      capture_log(fn ->
        restart_with_config(api_key: nil, environment_name: :test, exclude_envs: [])
      end)

    assert logged =~ ~s|[Honeybadger] Mandatory config key :api_key not set|
  end

  test "warn in an excluded env" do
    logged =
      capture_log(fn ->
        restart_with_config(environment_name: :test, exclude_envs: [:test])
      end)

    assert logged =~
             ~s|[Honeybadger] Development mode is enabled. Data will not be reported until you deploy your app.|
  end

  test "should not show warning if env is complete" do
    logged =
      capture_log(fn ->
        restart_with_config(api_key: "test", environment_name: :test, exclude_envs: [])
      end)

    refute logged =~ ~s|mandatory :honeybadger config key api_key not set|
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

  test "getting, setting and clearing the context" do
    assert Honeybadger.context() == %{}

    assert Honeybadger.context(user_id: 1) == %{user_id: 1}
    assert Honeybadger.context(%{user_id: 2}) == %{user_id: 2}
    assert Honeybadger.context() == %{user_id: 2}

    :ok = Honeybadger.clear_context()
    assert Honeybadger.context() == %{}
  end

  test "setting context with invalid data type" do
    assert_raise FunctionClauseError, fn ->
      Honeybadger.context(nil)
    end

    assert_raise FunctionClauseError, fn ->
      Honeybadger.context(true)
    end

    assert_raise FunctionClauseError, fn ->
      Honeybadger.context(3)
    end
  end
end
