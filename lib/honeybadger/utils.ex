defmodule Honeybadger.Utils do
  @moduledoc """
    Assorted helper functions used through out the Honeybadger package
  """

  @doc """
    Internally all modules are prefixed with Elixir. This function removes the
    Elixir prefix from the module when it is converted to a string.
  """
  def strip_elixir_prefix(module) do
    module
    |> Atom.to_string
    |> String.split(".")
    |> tl
    |> Enum.join(".")
  end

  @doc """
  Resolve environment name from Application configuration or from Mix.env
  """
  def environment_name do
    case Application.get_env(:honeybadger, :mix_env, nil) do
      nil ->
        Mix.env
      name ->
        name
    end
  end

end
