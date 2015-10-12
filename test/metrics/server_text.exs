defmodule MetricServerTest do
  use ExUnit.Case, async: true
  alias Honeybadger.Metrics

  test "adding and flushing request times" do
    Metrics.Server.timing(122)
    Metrics.Server.timing(87)

    server = Process.whereis(Metrics.Server)
    assert :sys.get_state(server) == %{timings: [87, 122], interval: 60000}

    send(server, :flush)
    assert :sys.get_state(server) == %{timings: [], interval: 60000}
  end

  test "being flushed by the scheduled interval" do
    {:ok, server} = Metrics.Server.start_link(10, :test_metrics_server)

    Metrics.Server.timing(122)
    Metrics.Server.timing(87)

    :timer.sleep(10)
    assert :sys.get_state(server) == %{timings: [], interval: 10}
  end
end
