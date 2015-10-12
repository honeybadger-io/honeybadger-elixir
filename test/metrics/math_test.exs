defmodule Metrics.MathTest do
  use ExUnit.Case, async: true
  alias Honeybadger.Metrics.Math

  setup do
    requests = [122, 87, 820, 45, 731]
    {:ok, %{requests: requests}}
  end

  test "mean", %{requests: requests} do
    assert 361.0 == Math.mean(requests)
    assert 0     == Math.mean([])
  end

  test "median", %{requests: requests} do
    assert 122 == Math.median(requests)
    assert 0   == Math.median([])
  end

  test "max", %{requests: requests} do
    assert 820 == Math.max(requests)
    assert 0   == Math.max([])
  end

  test "min", %{requests: requests} do
    assert 45 == Math.min(requests)
    assert 0  == Math.min([])
  end

  test "standard deviation", %{requests: requests} do
    assert 340.48 == Math.standard_deviation(requests)
    assert 0      == Math.standard_deviation([])
  end

  test "calculating the percentile", %{requests: requests} do
    assert 104.5 == Math.percentile(requests, 0.40)
    assert 820  == Math.percentile(requests, 0.90)
    assert Math.percentile(requests, 90) == Math.percentile(requests, 0.90)
    assert Math.percentile(requests, 50) == Math.percentile(requests, 0.50)
  end

end
