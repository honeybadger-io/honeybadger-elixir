defmodule HoneybadgerTest do
  use ExUnit.Case
  alias HTTPoison, as: HTTP
  require Honeybadger

  setup do
    before = Application.get_env :honeybadger, :api_key

    Application.put_env :honeybadger, :api_key, "at3stk3y"

    on_exit(fn ->
      Application.put_env :honeybadger, :api_key, before
    end)
  end

  test "sending a notice" do
    :meck.expect(HTTP, :post, fn(_url, _data, _headers) -> %HTTP.Response{} end)
    Application.put_env(:honeybadger, :exclude_envs, [])

    url = Application.get_env(:honeybadger, :origin) <> "/v1/notices"
    headers = [{"Accept", "application/json"},
               {"Content-Type", "application/json"},
               {"X-API-Key", "at3stk3y"}]

    defmodule Sample do
      def notify do
        Honeybadger.notify(%RuntimeError{}, %{})
      end
    end

    Sample.notify
    :timer.sleep 250

    assert :meck.called(HTTP, :post, [url, :_, headers])
  after
    Application.put_env(:honeybadger, :exclude_envs, [:dev, :test])
  end

  test "sending a metric" do
    :meck.expect(HTTP, :post, fn(_url, _data, _headers) -> %HTTP.Response{} end)
    Application.put_env(:honeybadger, :exclude_envs, [])

    url = Application.get_env(:honeybadger, :origin) <> "/v1/metrics"
    headers = [{"Accept", "application/json"},
               {"Content-Type", "application/json"},
               {"X-API-Key", "at3stk3y"}]

    defmodule Sample2 do
      def send_metric do
        metric = Honeybadger.Metric.new([15, 20, 23, 18, 44, 88, 6])
        Honeybadger.send_metric(metric)
      end
    end

    Sample2.send_metric
    :timer.sleep 250

    assert :meck.called(HTTP, :post, [url, :_, headers])
  after
    Application.put_env(:honeybadger, :exclude_envs, [:dev, :test])
  end

  test "getting and setting the context" do
    assert %{} == Honeybadger.context()

    Honeybadger.context(user_id: 1)
    assert %{user_id: 1} == Honeybadger.context()

    Honeybadger.context(%{user_id: 2})
    assert %{user_id: 2} == Honeybadger.context()
  end

  test "calls at compile time are removed in exclude environments" do
    assert [:dev, :test] == Application.get_env(:honeybadger, :exclude_envs)
    assert :ok == Honeybadger.notify(%RuntimeError{})
  end
end
