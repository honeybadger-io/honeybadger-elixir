defmodule Honeybadger.ExcludeErrors do
  @moduledoc """
  Specification of user overrideable exclude_errors function.
  """

  alias Honeybadger.Notice

  @doc """
  Takes in a notice struct and supposed to return true or false depending with the user Specification
  """
  @callback exclude_error?(Notice.t()) :: boolean
end
