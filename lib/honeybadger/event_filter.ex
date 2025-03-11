defmodule Honeybadger.EventFilter do
  @moduledoc """
  Specification for filtering instrumented events.

  Most users won't need this, but if you need complete control over
  filtering, implement this behaviour and configure like:

      config :honeybadger,
        event_filter: MyApp.MyEventFilter
  """

  @doc """
  Filters an instrumented event.

  ## Parameters

    * `metadata` - The current metadata for the event
    * `raw_event` - The raw event metadata
    * `event_name` - The name of the telemetry event being processed, in dot form "a.b.c"

  ## Returns

    The filtered metadata map that will be sent to Honeybadger
  """
  @callback filter(metadata :: map(), raw_event :: map(), event_name :: String.t()) :: map() | nil
end
