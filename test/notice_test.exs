defmodule Honeybadger.NoticeTest do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  use ExUnit.Case

  setup do
    exception = %RuntimeError{message: "Oops"}
    plug_env = %{
      url: "/pages/1",
      component: SomeApp.PageController,
      action: :show,
      params: %{page: 1}
    }
    metadata = %{plug_env: plug_env, tags: [:test], user_id: 1, account_id: 1}
    stack = [{Kernel, :+, [1], [file: 'lib/elixir/lib/kernel.ex', line: 321]}]
    backtrace = Backtrace.from_stacktrace(stack)

    notice = Notice.new(exception, metadata, backtrace)

    {:ok, [notice: notice]}
  end

  test "notifier information", %{notice: %Notice{notifier: notifier}} do
    assert "https://github.com/honeybadger-io/honeybadger-elixir" == notifier[:url]
    assert "Honeybadger Elixir Notifier" == notifier[:name]
    assert Honeybadger.Mixfile.project[:version] == notifier[:version]
  end

  test "server information", %{notice: %Notice{server: server}} do
    hostname = :inet.gethostname |> elem(1) |> List.to_string

    assert :test      == server[:environment_name]
    assert hostname   == server[:hostname]
    assert System.cwd == server[:project_root]
  end

  test "error information", %{notice: %Notice{error: error}} do
    assert "RuntimeError" == error[:class]
    assert "Oops"         == error[:message]
    assert [:test]        == error[:tags]
    assert [%{file: "lib/elixir/lib/kernel.ex", method: "+", number: 321}] == error[:backtrace]
  end

  test "request information", %{notice: %Notice{request: request}} do
    assert %{
      action: :show,
      component: SomeApp.PageController,
      params: %{page: 1},
      url: "/pages/1"
    } == request[:plug_env]

    assert %{user_id: 1, account_id: 1} == request[:context]
    refute [:test] == request[:tags]
  end
end
