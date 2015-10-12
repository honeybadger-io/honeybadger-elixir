defmodule Honeybadger.Metrics.Math do

  def mean([]), do: 0
  def mean(requests) do
    total = Enum.sum(requests)
    count = Enum.count(requests)
    total / count
  end

  def median([]), do: 0
  def median(requests) do
    middle = Enum.count(requests) |> div(2)
    requests 
    |> Enum.sort 
    |> Enum.at(middle)
  end

  def max([]), do: 0
  def max(requests), do: Enum.max(requests)

  def min([]), do: 0
  def min(requests), do: Enum.min(requests)

  def standard_deviation([]), do: 0
  def standard_deviation(requests) do
    variance(requests) 
    |> :math.sqrt
    |> Float.round(2)
  end

  def variance([]), do: 0
  def variance(requests) do
    squared_diff = Enum.reduce(requests, 0.0, fn(request, sum) ->
      diff = request - mean(requests)
      sum + (diff * diff)
    end)
    squared_diff / Enum.count(requests)
  end

  def percentile([]), do: 0

  def percentile(requests, k) 
  when is_integer(k)
  and k >= 0 and k <= 100 do
    percentile(requests, k * 0.01)
  end

  def percentile(requests, k) when is_float(k) do
    ordered = Enum.sort(requests)
    index = Enum.count(requests) * k

    case whole_number?(index) do
      true ->
        index = round(index)
        ordered
        |> Enum.slice(index - 1, 2) 
        |> mean
      false ->
        adjusted = Float.ceil(index) |> round
        Enum.at(ordered, adjusted - 1)
    end
  end

  defp whole_number?(num), do: round(num) == num
end
