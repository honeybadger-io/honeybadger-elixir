defmodule Mix.Tasks.Honeybadger.TestTest do
  use Honeybadger.Case

  setup do
    {:ok, _} = Honeybadger.API.start(self())
    on_exit(&Honeybadger.API.stop/0)

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  test "sends a test notice even when the current environment is excluded" do
    restart_with_config(environment_name: :test, exclude_envs: [:test])

    Mix.Tasks.Honeybadger.Test.run([])

    assert_receive {:api_request, %{"error" => %{"class" => "HoneybadgerTestingException"}}}
  end
end
