defmodule Honeybadger.FingerprintAdapter do
  @moduledoc """
  The callbacks required to implement the FingerprintAdapter behaviour
  """

  @doc """
  This function receives a `t:Notice.t/0` and must return a string that will be used as a
  fingerprint for the request:

  def parse(notice) do
    notice.notifier.language <> "_" <> notice.notifier.name
  end
  """
  @callback parse(Notice.noticeable()) :: String.t()
end
