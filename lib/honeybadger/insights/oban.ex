defmodule Honeybadger.Insights.Oban do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Oban]

  @telemetry_events [
    "oban.job.stop",
    "oban.job.exception"
  ]

  def extract_metadata(meta, _name) do
    Map.take(meta, [
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
