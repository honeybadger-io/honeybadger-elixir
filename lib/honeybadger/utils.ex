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

  @doc """
  Runs the given function inside a try and returns a tagged tuple with an
  {:ok, result} on success and {:error, err} on error

  # Example

      iex> Honeybadger.Utils.safe_exec(fn -> 3 * 3 end)
      {:ok, 9}

      iex> Honeybadger.Utils.safe_exec(fn -> raise "Danny is sleeping!" end)
      {:error, %RuntimeError{message: "Danny is sleeping!"}}
  """
  def safe_exec(fun) do
    try do
      {:ok, fun.()}
    rescue
      ex -> {:error, ex}
    end
  end

end
