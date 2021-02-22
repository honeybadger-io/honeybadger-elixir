defmodule Honeybadger.LoggerTest do
  use Honeybadger.Case

  require Logger

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    restart_with_config(exclude_envs: [], breadcrumbs_enabled: true)

    on_exit(&Honeybadger.API.stop/0)
  end

  test "GenServer terminating with an error" do
    defmodule MyGenServer do
      use GenServer

      def start_link(_opts) do
        GenServer.start(__MODULE__, %{}, name: Elixir.MyGenServer)
      end

      def init(opts), do: {:ok, opts}

      def handle_cast(:raise_error, state) do
        _ = Map.fetch!(state, :bad_key)

        {:noreply, state}
      end
    end

    {:ok, pid} = start_supervised(MyGenServer)

    GenServer.cast(pid, :raise_error)

    assert_receive {:api_request,
                    %{"breadcrumbs" => breadcrumbs, "error" => error, "request" => request}}

    assert List.first(breadcrumbs["trail"])["message"] == "KeyError"

    assert error["class"] == "KeyError"

    assert request["context"]["registered_name"] == "Elixir.MyGenServer"
    assert request["context"]["last_message"] =~ "$gen_cast"
    assert request["context"]["state"] == "%{}"
  end

  test "GenEvent terminating with an error" do
    defmodule MyEventHandler do
      @behaviour :gen_event

      def init(state), do: {:ok, state}
      def terminate(_reason, _state), do: :ok
      def code_change(_old_vsn, state, _extra), do: {:ok, state}
      def handle_call(_request, state), do: {:ok, :ok, state}
      def handle_info(_message, state), do: {:ok, state}

      def handle_event(:raise_error, state) do
        raise "Oops"

        {:ok, state}
      end
    end

    {:ok, manager} = :gen_event.start()
    :ok = :gen_event.add_handler(manager, MyEventHandler, {})

    :gen_event.notify(manager, :raise_error)

    assert_receive {:api_request,
                    %{"breadcrumbs" => breadcrumbs, "error" => error, "request" => request}}

    assert List.first(breadcrumbs["trail"])["message"] == "RuntimeError"

    assert error["class"] == "RuntimeError"

    assert request["context"]["name"] == "Honeybadger.LoggerTest.MyEventHandler"
    assert request["context"]["last_message"] =~ ":raise_error"
    assert request["context"]["state"] == "{}"
  end

  test "process raising an error" do
    pid = spawn(fn -> raise "Oops" end)

    assert_receive {:api_request,
                    %{"breadcrumbs" => breadcrumbs, "error" => error, "request" => request}}

    assert List.first(breadcrumbs["trail"])["message"] == "RuntimeError"

    assert error["class"] == "RuntimeError"

    assert request["context"]["name"] == inspect(pid)
  end

  test "task with anonymous function raising an error" do
    Task.start(fn -> raise "Oops" end)

    assert_receive {:api_request,
                    %{"breadcrumbs" => breadcrumbs, "error" => error, "request" => request}}

    assert List.first(breadcrumbs["trail"])["message"] == "RuntimeError"

    assert error["class"] == "RuntimeError"
    assert error["message"] == "Oops"

    assert request["context"]["function"] =~ ~r/\A#Function<.* in Honeybadger\.LoggerTest/
    assert request["context"]["args"] == "[]"
  end

  test "task with mfa raising an error" do
    defmodule MyModule do
      def raise_error(message), do: raise(message)
    end

    Task.start(MyModule, :raise_error, ["my message"])

    assert_receive {:api_request,
                    %{"breadcrumbs" => breadcrumbs, "error" => _, "request" => request}}

    assert List.first(breadcrumbs["trail"])["metadata"]["message"] == "my message"

    assert request["context"]["function"] =~ "&Honeybadger.LoggerTest.MyModule.raise_error/1"
    assert request["context"]["args"] == ~s(["my message"])
  end

  test "includes additional logger metadata as context" do
    Task.start(fn ->
      Logger.metadata(age: 2, name: "Danny", user_id: 3)

      raise "Oops"
    end)

    assert_receive {:api_request, %{"breadcrumbs" => breadcrumbs, "request" => request}}

    assert List.first(breadcrumbs["trail"])["metadata"]["message"] == "Oops"

    assert request["context"]["age"] == 2
    assert request["context"]["name"] == "Danny"
    assert request["context"]["user_id"] == 3
  end

  test "log levels lower than :error are ignored" do
    Logger.metadata(crash_reason: {%RuntimeError{}, []})

    Logger.info(fn -> "This is not a real error" end)

    refute_receive {:api_request, _}
  end

  test "handles error-level log" do
    Logger.error("Error-level log")

    assert_receive {:api_request, %{"breadcrumbs" => breadcrumbs}}
    assert List.first(breadcrumbs["trail"])["metadata"]["message"] == "Error-level log"
  end

  test "ignores specific logger domains" do
    with_config([ignored_domains: [:neat]], fn ->
      Task.start(fn ->
        Logger.error("what", domain: [:neat])
      end)

      refute_receive {:api_request, _}
    end)
  end
end
