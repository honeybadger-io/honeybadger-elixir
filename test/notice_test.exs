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
      params: %{page: 1, password: "123abc"}
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

  test "Honeybadger.DefaultFilter is active by default", %{notice: notice} do
    assert Application.get_env(:honeybadger, :notice_filter) == Honeybadger.DefaultNoticeFilter
    assert Application.get_env(:honeybadger, :filter) == Honeybadger.DefaultFilter
    assert Application.get_env(:honeybadger, :filter_keys) == [:password, :credit_card]

    refute get_in(notice.request, [:params, :password])
  end

  test "User implemented Filter works" do
    defmodule TestFilter do
      use Honeybadger.FilterMixin

      def filter_params(params),
        do: Map.drop(params, ["password"])

      def filter_error_message(message),
        do: Regex.replace(~r/(Secret data: )(\w+)/, message, "\\1 xxx")
    end

    orig_filter = Application.get_env :honeybadger, :filter
    Application.put_env :honeybadger, :filter, TestFilter
    on_exit fn -> Application.put_env(:honeybadger, :filter, orig_filter) end

    notice = filterable_notice()

    assert get_in(notice.request, [:context, :foo])
    refute get_in(notice.request, [:context, :password])
    refute get_in(notice.request, [:params, "password"])
    assert get_in(notice.request, [:params, "PaSSword"])
    assert get_in(notice.request, [:params, "credit_card"])
    refute notice.error.message =~ "XYZZY"
    refute get_in(notice.request, [:params, "token"])
  end

  test "Honeybadger.DefaultFilter filters according to config" do
    orig_keys   = Application.get_env :honeybadger, :filter_keys
    Application.put_env :honeybadger, :filter_keys, [:password, :credit_card, :authorization]
    on_exit fn -> Application.put_env(:honeybadger, :filter_keys, orig_keys) end

    notice = filterable_notice()

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
  end

  test "Honeybadger.DefaultFilter filters entire session if filter_disable_session is set" do
    orig_filter = Application.get_env :honeybadger, :filter
    orig_disable = Application.get_env :honeybadger, :filter_disable_session
    Application.put_env :honeybadger, :filter_disable_session, true
    on_exit fn ->
      Application.put_env(:honeybadger, :filter, orig_filter)
      Application.put_env(:honeybadger, :filter_disable_session, orig_disable)
    end

    notice = filterable_notice()
    assert get_in(notice.request, [:params])
    assert get_in(notice.request, [:url])
    refute get_in(notice.request, [:session])

    # Ensure normal filtering in other areas
    assert get_in(notice.request, [:context, :foo]) == "foo"
    refute get_in(notice.request, [:context, :password])

    assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
    refute get_in(notice.request, [:cgi_data, "PASSWORD"])

    assert get_in(notice.request, [:params, "unfiltered" ]) == "unfiltered"
    refute get_in(notice.request, [:params, "PaSSword"])
  end

  test "Honeybadger.DefaultFilter filters url if filter_disable_url is set" do
    orig_filter = Application.get_env :honeybadger, :filter
    orig_disable = Application.get_env :honeybadger, :filter_disable_url
    Application.put_env :honeybadger, :filter_disable_url, true
    on_exit fn ->
      Application.put_env(:honeybadger, :filter, orig_filter)
      Application.put_env(:honeybadger, :filter_disable_url, orig_disable)
    end

    notice = filterable_notice()
    assert get_in(notice.request, [:params])
    refute get_in(notice.request, [:url])
    assert get_in(notice.request, [:session])

    # Ensure normal filtering in other areas
    assert get_in(notice.request, [:context, :foo]) == "foo"
    refute get_in(notice.request, [:context, :password])

    assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
    refute get_in(notice.request, [:cgi_data, "PASSWORD"])

    assert get_in(notice.request, [:params, "unfiltered" ]) == "unfiltered"
    refute get_in(notice.request, [:params, "PaSSword"])

    assert get_in(notice.request, [:session, "not filtered"])
    refute get_in(notice.request, [:session, :password])
  end

  test "Honeybadger.DefaultFilter filters params if filter_disable_params is set" do
    orig_disable = Application.get_env :honeybadger, :filter_disable_params
    Application.put_env :honeybadger, :filter_disable_params, true
    on_exit fn ->
      Application.put_env(:honeybadger, :filter_disable_params, orig_disable)
    end

    notice = filterable_notice()

    refute get_in(notice.request, [:params])
    assert get_in(notice.request, [:url])
    assert get_in(notice.request, [:session])
    assert get_in(notice.request, [:cgi_data])

    # Ensure normal filtering in other areas
    assert get_in(notice.request, [:context, :foo]) == "foo"
    refute get_in(notice.request, [:context, :password])

    assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
    refute get_in(notice.request, [:cgi_data, "PASSWORD"])

    assert get_in(notice.request, [:session, "not filtered"])
    refute get_in(notice.request, [:session, :password])
  end

  test "Setting notice_filter to nil disables filtering" do
    orig_notice_filter = Application.get_env :honeybadger, :notice_filter
    Application.put_env :honeybadger, :notice_filter, nil
    on_exit fn ->
      Application.put_env(:honeybadger, :notice_filter, orig_notice_filter)
    end

    notice = filterable_notice()

    assert get_in(notice.request, [:params])
    assert get_in(notice.request, [:url])
    assert get_in(notice.request, [:session])
    assert get_in(notice.request, [:cgi_data])
    assert get_in(notice.request, [:context, :foo]) == "foo"
    assert get_in(notice.request, [:context, :password])
    assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
    assert get_in(notice.request, [:cgi_data, "PASSWORD"])
    assert get_in(notice.request, [:session, "not filtered"])
    assert get_in(notice.request, [:session, :password])
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
            "PASSWORD" => "Why is there a password Header? Just to test"},
          session: %{:credit_card => "1234",
                     "CREDIT_card" => "1234",
                     :password => "secret",
                     "not filtered" => :not_filtered},
        }
      }
      Notice.new(exception, metadata, backtrace)
  end
end
