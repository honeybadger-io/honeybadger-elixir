defmodule Honeybadger.FingerprintAdapter do
  @moduledoc """
  The callbacks required to implement the FingerprintAdapter behaviour
  """

  @doc """
  For applications that specifies a fingerprint_adapter. This function receives
  a Notice and must return a string that will be used as a fingerprint for the
  request:

  def parse(notice) do
    notice.notifier.language <> "_" <> notice.notifier.name
  end
  """
  @callback parse(Notice.noticeable()) :: String.t()
end
