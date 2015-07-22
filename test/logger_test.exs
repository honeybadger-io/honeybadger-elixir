defmodule Honeybadger.LoggerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  require Logger

  setup_all do
    :error_logger.add_report_handler(Honeybadger.Logger)

    on_exit fn ->
      :error_logger.delete_report_handler(Honeybadger.Logger)
    end
  end

  test "logging a crash" do
    :meck.expect(Honeybadger, :notify, fn(_ex, _c, _s) -> :ok end)

    :proc_lib.spawn(fn ->
      Honeybadger.context(user_id: 1)
      raise RuntimeError, "Oops"
    end)
    :timer.sleep 10
    
    assert :meck.called(Honeybadger, :notify, [:_, :_, :_])

    :meck.unload(Honeybadger)
  end

  test "crashes do not cause recursive logging" do
    :meck.expect(Honeybadger, :notify, fn(_ex, _c, _s) -> raise %HTTPoison.Error{reason: 500} end)

    error_report = [[error_info: {:error, %RuntimeError{message: "Oops"}, []},
                    dictionary: [honeybadger_context: [user_id: 1]]], []]
    :error_logger.error_report(error_report)
    :timer.sleep 10

    assert :meck.called(Honeybadger, :notify, [%RuntimeError{message: "Oops"}, 
                                               %{honeybadger_context: [user_id: 1]}, 
                                               []])

    :meck.unload(Honeybadger)
  end

  test "log levels lower than :error_report are ignored" do
    :meck.expect(Honeybadger, :notify, fn(_ex, _c, _s) -> :ok end)
    message_types = [:info_msg, :info_report, :warning_msg, :error_msg]

    Enum.each(message_types, fn(type) ->
      apply(:error_logger, type, ["Ignore me"]) 
      refute :meck.called(Honeybadger, :notify, [:_, :_, :_])
    end)

    :meck.unload(Honeybadger)
  end

  test "iodata and charlist messages are ignored" do
    :meck.expect(Honeybadger, :notify, fn(_ex, _c, _s) -> :ok end)

    Logger.error(["this", 'will', "be ignord"])
    :timer.sleep 10
    refute :meck.called(Honeybadger, :notify, [])
    Logger.error('this will also be ignored')
    :timer.sleep 10
    refute :meck.called(Honeybadger, :notify, [])

    :meck.unload(Honeybadger)
  end

  def capture_log(fun) do
    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  end
end
