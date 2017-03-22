defmodule Honeybadger.ClientTest do
  use ExUnit.Case, async: true
  alias Honeybadger.Client

  test "sending metrics" do
    client = Client.new
    metrics = [123, 456, 789, 134, 567, 890, 234, 567, 901]
    metric = Honeybadger.Metric.new(metrics)
    request = Client.send_metric(client, metric, FakeHttp)

    assert %{
      "body" => %{
        "metrics" => [
          "app.request.200:stddev #{metric.stddev}",
          "app.request.200:percentile_90 #{metric.percentile_90}",
          "app.request.200:min #{metric.min}",
          "app.request.200:median #{metric.median}",
          "app.request.200:mean #{metric.mean}",
          "app.request.200:max #{metric.max}",
          "app.request.200 #{metric.count}"
        ],
        "environment" => "test",
        "hostname" => Application.get_env(:honeybadger, :hostname)
      },
      "headers" => [
        {"X-API-Key", "abc123"},
        {"Accept", "application/json"},
        {"Content-Type", "application/json"}
      ],
      "url" => "https://localhost:4000/v1/metrics",
    } == request
  end
end
