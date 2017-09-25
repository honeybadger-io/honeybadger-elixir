defmodule Honeybadger.LoggerTest do
  use Honeybadger.Case

  require Logger

  defmodule ErrorServer do
    use GenServer

    def start do
      GenServer.start(__MODULE__, [])
    end

    def init(_), do: {:ok, []}

    def handle_cast(:fail, _state) do
      raise RuntimeError, "Crashing"
    end
  end

  setup_all do
    :error_logger.add_report_handler(Honeybadger.Logger)

    on_exit fn ->
      :error_logger.delete_report_handler(Honeybadger.Logger)
    end
  end

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    restart_with_config(exclude_envs: [])

    on_exit(&Honeybadger.API.stop/0)
  end

  test "logging a crash" do
    :proc_lib.spawn(fn ->
      Honeybadger.context(user_id: 1)
      raise RuntimeError, "Oops"
    end)

    assert_receive {:api_request, _}
  end

  test "crashes do not cause recursive logging" do
    error_report = [[error_info: {:error, %RuntimeError{message: "Oops"}, []},
                    dictionary: [honeybadger_context: [user_id: 1]]], []]

    log = capture_log(fn ->
      :error_logger.error_report(error_report)
    end)

    assert log =~ "Unable to notify Honeybadger!"

    refute_receive {:api_request, _}
  end

  test "log levels lower than :error_report are ignored" do
    message_types = [:info_msg, :info_report, :warning_msg, :error_msg]

    Enum.each(message_types, fn(type) ->
      apply(:error_logger, type, ["Ignore me"])
      Logger.flush()

      refute_receive {:api_request, _}
    end)
  end

  test "logging exceptions from Tasks" do
    Task.start(fn ->
      Float.parse("12.345e308")
    end)

    Logger.flush()

    assert_receive {:api_request, _}
  end

  test "logging exceptions from GenServers" do
    {:ok, pid} = ErrorServer.start

    GenServer.cast(pid, :fail)
    Logger.flush()

    assert_receive {:api_request, _}
  end
end
