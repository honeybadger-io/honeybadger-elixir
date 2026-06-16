defmodule Honeybadger.ExcludeErrors.Default do
  @moduledoc """
  The default implementation for the `exclude_errors` configuration. Doesn't
  exclude any error.
  """

  alias Honeybadger.ExcludeErrors

  @behaviour ExcludeErrors

  @impl ExcludeErrors
  def exclude_error?(_), do: false
end
