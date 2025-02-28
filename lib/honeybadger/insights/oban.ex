defmodule Honeybadger.Insights.Oban do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Oban]

  @telemetry_events [
    "oban.job.stop"
  ]

  def extract_metadata(meta, _name) do
    meta
    |> Map.take([
      :args,
      :attempt,
      :id,
      :memory,
      :prefix,
      :queue,
      :queue_time,
      :state,
      :tags,
      :time,
      :worker
    ])
  end
end
