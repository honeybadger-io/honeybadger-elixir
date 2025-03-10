defmodule Honeybadger.Insights.Oban do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Oban]

  @telemetry_events [
    "oban.job.stop",
    "oban.job.exception"
  ]

  def extract_metadata(%{conf: conf, job: job, state: state}, _name) do
    job
    |> Map.take(~w(args attempt id queue tags worker)a)
    |> Map.put(:prefix, conf.prefix)
    |> Map.put(:state, state)
  end
end
