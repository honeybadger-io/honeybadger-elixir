defmodule Honeybadger.FingerprintAdapter do
  @moduledoc """
  The callbacks required to implement the FingerprintAdapter behaviour
  """

  @callback parse(Notice.noticeable()) :: String.t()
end
