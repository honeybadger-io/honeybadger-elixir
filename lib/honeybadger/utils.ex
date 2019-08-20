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
  Transform value into a consistently cased string representation
  """
  def canonicalize(val) do
    val
    |> to_string()
    |> String.downcase()
  end

  @doc """
  Configurable data sanitization. This currently:

  - recursively truncates deep structures (to a depth of 20)
  - constrains large string values (to 64k)
  - filters out any map keys that might contain sensitive information.
  """
  @default_max_string_size 65526
  @default_max_depth 20

  @depth_token "[DEPTH]"
  @truncated_token "[TRUNCATED]"
  @filtered_token "[FILTERED]"

  def sanitize(value, opts \\ []) do
    base = %{
      max_depth: @default_max_depth,
      max_string_size: @default_max_string_size,
      filter_keys: Honeybadger.get_env(:filter_keys)
    }

    opts =
      Enum.into(opts, base)
      |> Map.update!(:filter_keys, fn v -> MapSet.new(v, &canonicalize/1) end)

    sanitize_val(value, Map.put(opts, :depth, 0))
  end

  defp sanitize_val(v, %{depth: depth, max_depth: depth}) when is_map(v) or is_list(v) do
    @depth_token
  end

  defp sanitize_val(%{__struct__: _} = struct, opts) do
    sanitize_val(Map.from_struct(struct), opts)
  end

  defp sanitize_val(v, %{depth: depth, filter_keys: filter_keys} = opts) when is_map(v) do
    Enum.reduce(v, %{}, fn {key, value}, acc ->
      Map.put(
        acc,
        key,
        if MapSet.member?(filter_keys, canonicalize(key)) do
          @filtered_token
        else
          sanitize_val(value, Map.put(opts, :depth, depth + 1))
        end
      )
    end)
  end

  defp sanitize_val(v, %{depth: depth} = opts) when is_list(v) do
    Enum.map(v, &sanitize_val(&1, Map.put(opts, :depth, depth + 1)))
  end

  defp sanitize_val(v, %{max_string_size: max_string_size} = opts) when is_binary(v) do
    if String.valid?(v) and String.length(v) > max_string_size do
      String.slice(v, 0, max_string_size) <> @truncated_token
    else
      v
    end
  end

  defp sanitize_val(v, opts), do: v
end
