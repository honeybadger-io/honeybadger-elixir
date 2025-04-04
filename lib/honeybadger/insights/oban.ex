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
           [:oban, :job, :stop],
           [:oban, :job, :exception],
           [:oban, :engine, :start]
         ]
       }
     }
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Oban]

  @telemetry_events [
    [:oban, :job, :stop],
    [:oban, :job, :exception]
  ]

  ## Public API

  @doc """
  Adds the current Honeybadger request ID to the job's metadata.

  ## Example

      MyApp.Worker.new()
      |> Honeybadger.Insights.Oban.add_request_id()
      |> Oban.insert()
  """
  def add_request_id(changeset) do
    meta =
      changeset
      |> Ecto.Changeset.get_field(:meta, %{})
      |> Map.put("hb_request_id", Honeybadger.get_request_id())

    Ecto.Changeset.put_change(changeset, :meta, meta)
  end

  ## Overridable Telemetry Handlers (Internal)
  #
  def get_telemetry_events() do
    events = get_insights_config(:telemetry_events, @telemetry_events)

    [[:oban, :job, :start]] ++ events
  end

  @doc false
  def extract_metadata(%{conf: conf, job: job, state: state}, _event) do
    job
    |> Map.take(~w(args attempt id queue tags worker)a)
    |> Map.put(:prefix, conf.prefix)
    |> Map.put(:state, state)
  end

  @doc false
  def handle_telemetry([:oban, :job, :start] = event, measurements, metadata, opts) do
    if request_id = metadata.job.meta["hb_request_id"] do
      Honeybadger.put_request_id(request_id)
    else
      Honeybadger.RequestId.inherit_or_initialize()
    end

    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end
  end
end
