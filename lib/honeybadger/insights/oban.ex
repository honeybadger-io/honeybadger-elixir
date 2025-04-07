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
  Adds the current Honeybadger event context to the Oban job's metadata.

  ## Example

      MyApp.Worker.new()
      |> Honeybadger.Insights.Oban.add_event_context()
      |> Oban.insert()
  """
  def add_event_context(changeset) do
    meta =
      changeset
      |> Ecto.Changeset.get_field(:meta, %{})
      |> Map.put("hb_event_context", Honeybadger.event_context())

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
    if event_context = metadata.job.meta["hb_event_context"] do
      Honeybadger.event_context(event_context)
    else
      Honeybadger.inherit_event_context()
    end

    Honeybadger.EventContext.put_new(:request_id, fn ->
      Honeybadger.Utils.rand_id()
    end)

    if event in get_insights_config(:telemetry_events, @telemetry_events) do
      handle_event_impl(event, measurements, metadata, opts)
    end
  end
end
