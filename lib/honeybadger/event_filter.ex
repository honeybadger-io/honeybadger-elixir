defmodule Honeybadger.EventFilter do
  @moduledoc """
  Specification for filtering instrumented events.

  Most users won't need this, but if you need complete control over
  filtering, implement this behaviour and configure like:

      config :honeybadger,
        event_filter: MyApp.MyEventFilter
  """

  @callback filter(map(), String.t()) :: map()
end
