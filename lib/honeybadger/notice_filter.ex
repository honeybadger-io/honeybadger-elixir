defmodule Honeybadger.NoticeFilter do
  @moduledoc """
  Specification for a top level `Honeybadger.Notice` filter.

  Most users won't need this, but if you need complete control over
  filtering, implement this behaviour and configure like:

      config :honeybadger,
        notice_filter: MyApp.MyNoticeFilter
  """

  @callback filter(Honeybadger.Notice.t()) :: Honeybadger.Notice.t()
end
