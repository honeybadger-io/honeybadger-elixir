defmodule Honeybadger.ExcludeErrors do
  @moduledoc """
  Specification of user overrideable exclude_errors function.
  """

  alias Honeybadger.Notice

  @doc """
  Filter the context Map.  The context is a map of application supplied data.
  """
  @callback exclude_error?(Notice.t()) :: boolean
end
