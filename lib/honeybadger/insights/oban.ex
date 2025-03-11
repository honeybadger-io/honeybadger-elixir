defmodule Honeybadger.Insights.Oban do
  @moduledoc """
  Captures telemetry events from Oban job processing.

  ## Default Configuration

  By default, this module listens for the following Oban telemetry events:

     "oban.job.stop"
     "oban.job.exception"

  ## Custom Configuration

  You can customize the telemetry events to listen for by updating the insights_config:

     config :honeybadger, insights_config: %{
       oban: %{
         telemetry_events: [
           "oban.job.stop",
           "oban.job.exception",
           "oban.engine.start"
         ]
       }
     }
  """

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
