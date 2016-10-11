defmodule Honeybadger.NoticeTest do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  use ExUnit.Case, async: true

  setup do
    exception = %RuntimeError{message: "Oops"}
    plug_env = %{
      url: "/pages/1",
      component: SomeApp.PageController,
      action: :show,
      params: %{page: 1}
    }
    metadata = %{plug_env: plug_env, tags: [:test], context: %{user_id: 1, account_id: 1}}
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

  test "server information config", _ do
    before = Application.get_env(:honeybadger, :environment_name)
    Application.put_env(:honeybadger, :environment_name, "foo")
    %Notice{server: server} = Notice.new(%RuntimeError{message: "Oops"}, %{}, [])
    Application.put_env(:honeybadger, :environment_name, before)
    assert "foo" == server[:environment_name]
  end

  test "error information", %{notice: %Notice{error: error}} do
    assert "RuntimeError" == error[:class]
    assert "Oops"         == error[:message]
    assert [:test]        == error[:tags]
    assert [%{file: "lib/elixir/lib/kernel.ex", method: "+", number: 321, context: "all"}] == error[:backtrace]
  end

  test "request information", %{notice: %Notice{request: request}} do
    assert %{
      action: :show,
      component: SomeApp.PageController,
      params: %{page: 1},
      url: "/pages/1"
    } == Dict.drop(request, [:context])

    assert %{user_id: 1, account_id: 1} == request[:context]
    refute [:test] == request[:tags]
  end

  test "erlang error normalization", _ do
    %{error: %{class: class}} = Notice.new(:badarg, %{}, nil)
    assert class == "ArgumentError"
  end

  test "filter works on context, message and params", %{notice: n} do
    defmodule TestFilter do
      use Honeybadger.Filter
      def filter_context(context), do: Map.drop(context, [:password])
      def filter_error_message(message),
        do: Regex.replace(~r/(Secret Data: )(\w+)/, message, "\\1 xxx")
      def filter_params(params), do: Map.drop(params, ["token"])
    end

    orig_filter = Application.get_env :honeybadger, :filter
    Application.put_env :honeybadger, :filter, TestFilter

    exception = %RuntimeError{message: "Secret data: XYZZY"}
    metadata = %{plug_env: %{params: %{"token" => "123456"}},
                 tags: [],
                 context: %{password: "123", foo: "foo"}}
    notice = Notice.new(exception, metadata, [])

    assert get_in(notice.request, [:context, :foo])
    refute get_in(notice.request, [:context, :password])
    refute notice.error.message == "XYZZY"
    refute get_in(notice.request, [:params, "token"])
    on_exit(fn ->
      Application.put_env :honeybadger, :filter, orig_filter
    end)
  end
end
