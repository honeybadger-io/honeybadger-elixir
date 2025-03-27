defmodule Honeybadger.EventFilter do
  @moduledoc """
  Specification for filtering instrumented events.

  Most users won't need this, but if you need complete control over
  filtering, implement this behaviour and configure like:

      config :honeybadger,
        event_filter: MyApp.MyEventFilter
  """

  @doc """
  Filters an instrumented telemetry event.

  ## Parameters

    * `data` - The current data for the event
    * `raw_event` - The raw event metadata
    * `event` - The telemetry event being processed, e.g. [:phoenix, :endpoint, :start]

  ## Returns

    The filtered metadata map that will be sent to Honeybadger or `nil` to skip
    the event.
  """
  @callback filter_telemetry_event(data :: map(), raw_event :: map(), event :: [atom(), ...]) ::
              map() | nil
end
