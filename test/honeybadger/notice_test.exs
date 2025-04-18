defmodule Honeybadger.NoticeTest do
  use Honeybadger.Case, async: false

  doctest Honeybadger.Notice

  alias Honeybadger.Notice
  alias Honeybadger.Breadcrumbs.Breadcrumb

  setup do
    exception = %RuntimeError{message: "Oops"}

    plug_env = %{
      url: "/pages/1",
      component: SomeApp.PageController,
      action: :show,
      params: %{page: 1, password: "123abc"}
    }

    metadata = %{plug_env: plug_env, tags: [:test], context: %{user_id: 1, account_id: 1}}
    stack = [{Kernel, :+, [1], [file: ~c"lib/elixir/lib/kernel.ex", line: 321]}]

    notice = Notice.new(exception, metadata, stack)

    {:ok, [notice: notice]}
  end

  test "notifier information", %{notice: %Notice{notifier: notifier}} do
    assert "https://github.com/honeybadger-io/honeybadger-elixir" == notifier[:url]
    assert "honeybadger-elixir" == notifier[:name]
    assert "elixir" == notifier[:language]
    assert Honeybadger.Mixfile.project()[:version] == notifier[:version]
  end

  test "server information", %{notice: %Notice{server: server}} do
    hostname = :inet.gethostname() |> elem(1) |> List.to_string()

    assert :test == server[:environment_name]
    assert hostname == server[:hostname]
    assert File.cwd!() == server[:project_root]
  end

  test "server information config", _ do
    with_config([environment_name: "foo"], fn ->
      %Notice{server: server} = Notice.new(%RuntimeError{message: "Oops"}, %{}, [])

      assert "foo" == server[:environment_name]
    end)
  end

  test "with breadcrumbs", _ do
    breadcrumbs = %{
      enabled: true,
      trail: []
    }

    %Notice{breadcrumbs: to_breadcrumbs} =
      Notice.new(%RuntimeError{message: "Oops"}, %{breadcrumbs: breadcrumbs}, [])

    assert breadcrumbs == to_breadcrumbs
  end

  test "with request_id", _ do
    request_id = "1234"

    %Notice{correlation_context: correlation_context} =
      Notice.new(%RuntimeError{message: "Oops"}, %{request_id: request_id}, [])

    assert correlation_context == %{request_id: request_id}
  end

  test "error information", %{notice: %Notice{error: error}} do
    assert "RuntimeError" == error[:class]
    assert "Oops" == error[:message]
    assert [:test] == error[:tags]

    assert [
             %{
               file: "lib/elixir/lib/kernel.ex",
               method: "+/1",
               args: ["1"],
               number: 321,
               context: "all"
             }
           ] == error[:backtrace]
  end

  test "request information", %{notice: %Notice{request: request}} do
    assert %{
             action: :show,
             component: SomeApp.PageController,
             params: %{page: 1},
             url: "/pages/1"
           } == Map.drop(request, [:context])

    assert %{user_id: 1, account_id: 1} == request[:context]
    refute [:test] == request[:tags]
  end

  test "erlang error normalization", _ do
    %{error: %{class: class}} = Notice.new(:badarg, %{}, [])

    assert class == "ArgumentError"
  end

  test "default active filters", %{notice: notice} do
    assert Honeybadger.get_env(:notice_filter) == Honeybadger.NoticeFilter.Default
    assert Honeybadger.get_env(:filter) == Honeybadger.Filter.Default

    assert Honeybadger.get_env(:filter_keys) == [
             :password,
             :credit_card,
             :__changed__,
             :flash,
             :_csrf_token
           ]

    refute get_in(notice.request, [:params, :password])
  end

  test "user implemented filter works" do
    defmodule TestFilter do
      use Honeybadger.Filter.Mixin

      def filter_params(params), do: Map.drop(params, ["password"])

      def filter_error_message(message),
        do: Regex.replace(~r/(Secret data: )(\w+)/, message, "\\1 xxx")

      def filter_breadcrumbs(_breadcrumbs), do: [999]
    end

    with_config([filter: TestFilter], fn ->
      notice = filterable_notice()

      assert get_in(notice.request, [:context, :foo])
      refute get_in(notice.request, [:context, :password])
      refute get_in(notice.request, [:params, "password"])
      assert get_in(notice.request, [:params, "PaSSword"])
      assert get_in(notice.request, [:params, "credit_card"])
      refute notice.error.message =~ "XYZZY"
      refute get_in(notice.request, [:params, "token"])
      assert notice.breadcrumbs.trail == [999]
    end)
  end

  test "Honeybadger.Filter.Default filters according to config" do
    with_config([filter_keys: [:password, :credit_card, :authorization]], fn ->
      notice = filterable_notice()

      # It leaves unfiltered elements alone
      assert get_in(notice.request, [:context, :foo]) == "foo"
      assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
      assert get_in(notice.request, [:params, "unfiltered"]) == "unfiltered"

      # It filters sensitive data
      refute get_in(notice.request, [:context, :password])
      refute get_in(notice.request, [:cgi_data, "PASSWORD"])
      refute get_in(notice.request, [:cgi_data, "Authorization"])
      refute get_in(notice.request, [:cgi_data, "credit_card"])
      refute get_in(notice.request, [:params, "password"])
      refute get_in(notice.request, [:params, "PaSSword"])
      refute get_in(notice.request, [:session, :password])
    end)
  end

  test "Honeybadger.Filter.Default filters entire session if filter_disable_session is set" do
    with_config([filter_disable_session: true], fn ->
      notice = filterable_notice()
      assert get_in(notice.request, [:params])
      assert get_in(notice.request, [:url])
      refute get_in(notice.request, [:session])

      # Ensure normal filtering in other areas
      assert get_in(notice.request, [:context, :foo]) == "foo"
      refute get_in(notice.request, [:context, :password])

      assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
      refute get_in(notice.request, [:cgi_data, "PASSWORD"])

      assert get_in(notice.request, [:params, "unfiltered"]) == "unfiltered"
      refute get_in(notice.request, [:params, "PaSSword"])
    end)
  end

  test "Honeybadger.Filter.Default filters url if filter_disable_url is set" do
    with_config([filter_disable_url: true], fn ->
      notice = filterable_notice()

      assert get_in(notice.request, [:params])
      refute get_in(notice.request, [:url])
      assert get_in(notice.request, [:session])

      # Ensure normal filtering in other areas
      assert get_in(notice.request, [:context, :foo]) == "foo"
      refute get_in(notice.request, [:context, :password])

      assert get_in(notice.request, [:cgi_data, "HTTP_HOST"]) == "honeybadger.io"
      refute get_in(notice.request, [:cgi_data, "PASSWORD"])
      refute get_in(notice.request, [:cgi_data, "ORIGINAL_FULLPATH"])
      refute get_in(notice.request, [:cgi_data, "QUERY_STRING"])
      refute get_in(notice.request, [:cgi_data, "PATH_INFO"])

      assert get_in(notice.request, [:params, "unfiltered"]) == "unfiltered"
      refute get_in(notice.request, [:params, "PaSSword"])

      assert get_in(notice.request, [:session, "not filtered"])
      refute get_in(notice.request, [:session, :password])
    end)
  end

  test "Honeybadger.Filter.Default filters params if filter_disable_params is set" do
    with_config([filter_disable_params: true], fn ->
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
    end)
  end

  test "setting notice_filter to nil disables filtering" do
    with_config([notice_filter: nil], fn ->
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
    end)
  end

  defp filterable_notice do
    exception = %RuntimeError{message: "Secret data: XYZZY"}
    backtrace = []

    metadata = %{
      context: %{password: "123", foo: "foo"},
      breadcrumbs: %{
        active: true,
        trail: [
          Breadcrumb.new("my message", %{})
        ]
      },
      plug_env: %{
        url: "/some/secret/place",
        component: SomeApp.PageController,
        action: :show,
        params: %{
          "password" => "a password",
          "credit_card" => "1234",
          "PaSSword" => "WhAtevER",
          "unfiltered" => "unfiltered"
        },
        cgi_data: %{
          "HTTP_HOST" => "honeybadger.io",
          "Authorization" => "Basic whatever",
          "PASSWORD" => "Why is there a password Header? Just to test",
          "ORIGINAL_FULLPATH" => "/some/secret/place",
          "QUERY_STRING" => "foo=bar",
          "PATH_INFO" => "some/secret/place"
        },
        session: %{
          :credit_card => "1234",
          "CREDIT_card" => "1234",
          :password => "secret",
          "not filtered" => :not_filtered
        }
      }
    }

    Notice.new(exception, metadata, backtrace)
  end
end
