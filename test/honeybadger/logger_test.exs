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

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    restart_with_config(exclude_envs: [])

    on_exit(&Honeybadger.API.stop/0)
  end

  test "logging a crash" do
    Task.start(fn -> raise RuntimeError, "Oops" end)

    assert_receive {:api_request, notification}

    assert %{"error" => %{"class" => "RuntimeError"}} = notification
  end

  test "includes logger metadata as context" do
    Task.start(fn ->
      Logger.metadata(age: 2, name: "Danny", user_id: 3)

      raise RuntimeError, "Oops"
    end)

    assert_receive {:api_request, notification}

    %{"error" => error, "request" => %{"context" => context}} = notification

    assert %{"class" => "RuntimeError"} = error
    assert %{"age" => 2, "name" => "Danny", "user_id" => 3} = context
  end

  test "log levels lower than :error are ignored" do
    Logger.metadata(crash_reason: {%RuntimeError{}, []})

    Logger.info(fn -> "This is not a real error" end)

    refute_receive {:api_request, _}
  end

  # GenServer terminating with an Elixir error
  # GenServer terminating with an Erlang error
  # GenServer terminating because of an exit
  # GenServer stopping
  # GenEvent terminating
  # Process raising an error
  # Task with anonymous function raising an error
  # Task with mfa raising an error

  test "logging exceptions from GenServers" do
    {:ok, pid} = ErrorServer.start()

    GenServer.cast(pid, :fail)

    assert_receive {:api_request, %{"error" => %{"class" => "RuntimeError"}}}
  end
end
