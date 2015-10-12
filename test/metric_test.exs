defmodule Honeybadger.MetricTest do
  use ExUnit.Case
  alias Honeybadger.Metric

  test "creating metrics from a list of response times" do
    responses = [122, 87, 820, 45, 731]

    metric = Metric.new(responses)

    assert metric == %Metric{
      max: 820,
      mean: 361.0,
      median: 122,
      min: 45, 
      percentile_90: 820, 
      stddev: 340.48,
      count: 5}
  end
end
