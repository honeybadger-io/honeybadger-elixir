defmodule Honeybadger.NoticeTest do
  alias Honeybadger.Backtrace
  alias Honeybadger.Notice
  use ExUnit.Case, async: false

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

  test "Honyebadger.Filter works on context, message and params" do
    defmodule TestFilter do
      use Honeybadger.Filter
      def filter_context(context), do: Map.drop(context, [:password])
      def filter_error_message(message),
        do: Regex.replace(~r/(Secret data: )(\w+)/, message, "\\1 xxx")
      def filter_params(params), do: Map.drop(params, ["token"])
    end

    orig_filter = Application.get_env :honeybadger, :filter

    Application.put_env :honeybadger, :filter, TestFilter

    # Must create notice after filter is set
    notice = filterable_notice

    assert get_in(notice.request, [:context, :foo])
    refute get_in(notice.request, [:context, :password])
    refute notice.error.message =~ "XYZZY"
    refute get_in(notice.request, [:params, "token"])

    on_exit fn -> Application.put_env(:honeybadger, :filter, orig_filter) end
  end

  test "Honeybadger.DefaultFilter filters according to config" do
    orig_filter = Application.get_env :honeybadger, :filter
    orig_keys   = Application.get_env :honeybadger, :filter_keys
    Application.put_env :honeybadger, :filter, Honeybadger.DefaultFilter
    Application.put_env :honeybadger, :filter_keys, [:password, :credit_card, :authorization]

    notice = filterable_notice

    # It leaves unfiltered elements alone
    assert get_in(notice.request, [:context, :foo]) == "foo"
    assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
    assert get_in(notice.request, [:params, "unfiltered" ]) == "unfiltered"

    # It filters sensitive data
    refute get_in(notice.request, [:context, :password])
    refute get_in(notice.request, [:cgi_data, "PASSWORD"])
    refute get_in(notice.request, [:cgi_data, "Authorization"])
    refute get_in(notice.request, [:cgi_data, "credit_card"])
    refute get_in(notice.request, [:params, "password"])
    refute get_in(notice.request, [:params, "PaSSword"])
    refute get_in(notice.request, [:session, :password])

    on_exit fn ->
      Application.put_env(:honeybadger, :filter, orig_filter)
      Application.put_env(:honeybadger, :filter_keys, orig_keys)
    end
  end

  test "Honeybadger.DefaultFilter filters entire session if filter_disable_session is set" do
    orig_filter = Application.get_env :honeybadger, :filter
    orig_disable = Application.get_env :honeybadger, :filter_disable_session
    Application.put_env :honeybadger, :filter, Honeybadger.DefaultFilter
    Application.put_env :honeybadger, :filter_disable_session, true

    notice = filterable_notice

    refute get_in(notice.request, [:session])

    on_exit fn ->
      Application.put_env(:honeybadger, :filter, orig_filter)
      Application.put_env(:honeybadger, :filter_disable_session, orig_disable)
    end
  end

  test "Honeybadger.DefaultFilter filters url if filter_disable_url is set" do
    orig_filter = Application.get_env :honeybadger, :filter
    orig_disable = Application.get_env :honeybadger, :filter_disable_url
    Application.put_env :honeybadger, :filter, Honeybadger.DefaultFilter
    Application.put_env :honeybadger, :filter_disable_url, true

    notice = filterable_notice

    refute get_in(notice.request, [:url])

    on_exit fn ->
      Application.put_env(:honeybadger, :filter, orig_filter)
      Application.put_env(:honeybadger, :filter_disable_url, orig_disable)
    end
  end

  test "Honeybadger.DefaultFilter filters params if filter_disable_params is set" do
    orig_filter = Application.get_env :honeybadger, :filter
    orig_disable = Application.get_env :honeybadger, :filter_disable_params
    Application.put_env :honeybadger, :filter, Honeybadger.DefaultFilter
    Application.put_env :honeybadger, :filter_disable_params, true

    notice = filterable_notice

    refute get_in(notice.request, [:params])

    on_exit fn ->
      Application.put_env(:honeybadger, :filter, orig_filter)
      Application.put_env(:honeybadger, :filter_disable_params, orig_disable)
    end
  end

  defp filterable_notice do
      exception = %RuntimeError{message: "Secret data: XYZZY"}
      backtrace = []
      metadata = %{
        context: %{password: "123", foo: "foo"},

        plug_env: %{
          url: "/some/secret/place",
          component: SomeApp.PageController,
          action: :show,
          params: %{"password" => "a password",
                    "credit_card" => "1234",
                    "PaSSword" => "WhAtevER",
                    "unfiltered" => "unfiltered"},
          cgi_data: %{
            "HTTP_HOST" => "honeybadger.io",
            "Authorization" => "Basic whatever",
            "PASSWORD" => "Why is there a password Header?"},
          session: %{:credit_card => "1234",
                     "CREDIT_card" => "1234",
                     :password => "secret",
                     "not filtered" => :not_filtered},
        }
      }
      Notice.new(exception, metadata, backtrace)
  end
end
