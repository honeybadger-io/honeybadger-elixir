defmodule Honeybadger.LoggerTest do
  use ExUnit.Case
  alias HTTPoison, as: HTTP
  require Logger

  setup_all do
    :error_logger.add_report_handler(Honeybadger.Logger)
    Application.put_env(:honeybadger, :exclude_envs, [])
    # We re-require this file so the module will be re-compiled
    # to reflect the new `exclude_envs` setting
    Code.require_file("lib/honeybadger/logger.ex")

    on_exit fn ->
      :error_logger.delete_report_handler(Honeybadger.Logger)
      Application.put_env(:honeybadger, :exclude_envs, [:dev, :test])
    end
  end

  test "logging a crash" do
    :meck.expect(HTTP, :post, fn(_ex, _c, _s) -> %HTTP.Response{} end)

    :proc_lib.spawn(fn ->
      Honeybadger.context(user_id: 1)
      raise RuntimeError, "Oops"
    end)
    :timer.sleep 250

    assert :meck.called(HTTP, :post, [:_, :_, :_])
    :meck.unload(HTTP)
  end

  test "crashes do not cause recursive logging" do
    :meck.expect(HTTP, :post, fn(_ex, _c, _s) -> %HTTP.Error{reason: 500} end)

    error_report = [[error_info: {:error, %RuntimeError{message: "Oops"}, []},
                    dictionary: [honeybadger_context: [user_id: 1]]], []]
    :error_logger.error_report(error_report)
    :timer.sleep 250

    assert :meck.called(HTTP, :post, [:_, :_, :_])
    :meck.unload(HTTP)
  end

  test "log levels lower than :error_report are ignored" do
    message_types = [:info_msg, :info_report, :warning_msg, :error_msg]

    Enum.each(message_types, fn(type) ->
      :meck.expect(HTTP, :post, fn(_ex, _c, _s) -> %HTTP.Response{} end)
      apply(:error_logger, type, ["Ignore me"])
      :timer.sleep 100
      refute :meck.called(HTTP, :post, [:_, :_, :_])
    end)

    :meck.unload(HTTP)
  end

  test "logging erlang exceptions" do
    :meck.expect(HTTP, :post, fn(_ex, _c, _s) -> %HTTP.Response{} end)

    :proc_lib.spawn(fn ->
      Float.parse("12.345e308")
    end)
    :timer.sleep 250

    assert :meck.called(HTTP, :post, [:_, :_, :_])
    :meck.unload(HTTP)
  end
end
