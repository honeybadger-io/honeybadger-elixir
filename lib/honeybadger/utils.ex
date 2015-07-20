defmodule Honeybadger.Utils do
  @moduledoc """
    Assorted helper functions used through out the Honeybadger package
  """

  @exception_format ~r/\((?<type>.*?)\) (?<message>(.*))/

  @doc """
    Internally all modules are prefixed with Elixir. This
    function removes the Elixir prefix.
  """
  def strip_elixir_prefix(module) do
    module
    |> Atom.to_string
    |> String.split(".")
    |> tl
    |> Enum.join(".")
  end

  @doc """
    Takes an error message from the logger and tries to convert it back into
    the exception struct with its message in place.
  """
  def exception_from_message(message) do
    error = @exception_format
            |> Regex.named_captures(message)
            |> atomize_keys 

    error_mod = error[:type]
                |> String.split(".") 
                |> Module.safe_concat

    message_key = struct(error_mod) |> message_key_for_exception
    error = Dict.put(error, message_key, error[:message])
    error_mod.exception(error)
  end

  @doc """
    Takes a Dict and turns string keys into atom keys
  """
  def atomize_keys(dict) do
    Enum.map(dict, fn
      ({key, value} = entry) when is_atom(key) ->
        entry
      ({key, value}) ->
        {String.to_atom(key), value}
    end)
  end

  defp message_key_for_exception(%{__struct__: _, message: _}), do: :message
  defp message_key_for_exception(%{__struct__: _, reason: _}), do: :reason
end
