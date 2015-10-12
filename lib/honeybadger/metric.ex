defmodule Honeybadger.Metric do
  alias Honeybadger.Metrics.Math

  defstruct [:count, :max, :mean, :median, :min, :percentile_90, :stddev]

  def new(responses) do
    %__MODULE__{
      count: Enum.count(responses),
      max: Math.max(responses),
      mean: Math.mean(responses),
      median: Math.median(responses),
      min: Math.min(responses),
      percentile_90: Math.percentile(responses, 90),
      stddev: Math.standard_deviation(responses),
    }
  end
end

defimpl Poison.Encoder, for: Honeybadger.Metric do

  def encode(metric, _options) do
    metric
    |> Map.from_struct
    |> Map.drop([:count])
    |> Enum.reduce(["app.request.200 #{metric.count}"], fn({metric, value}, acc) ->
         ["app.request.200:" <> "#{metric} #{value}" | acc]
       end)
    |> Poison.encode!
  end

end
