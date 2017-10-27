defmodule Honeybadger.Filter.Default do
  @moduledoc """
  The default implementation for the `filter` configuration.  Removes
  keys listed in `filter_keys` from maps and respects the
  `filter_disable_*` configuration values.
  """

  use Honeybadger.Filter.Mixin
end
