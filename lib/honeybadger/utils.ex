defmodule Honeybadger.Utils do
  @moduledoc """
  Assorted helper functions used through out the Honeybadger package.
  """

  @doc """
  Internally all modules are prefixed with Elixir. This function removes the
  `Elixir` prefix from the module when it is converted to a string.

  # Example

      iex> Honeybadger.Utils.module_to_string(Honeybadger.Utils)
      "Honeybadger.Utils"
  """
  def module_to_string(module) do
    module
    |> Module.split()
    |> Enum.join(".")
  end
end
