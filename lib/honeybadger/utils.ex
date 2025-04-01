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
  Concatenate a list of items with a dot separator.

  # Example

      iex> Honeybadger.Utils.dotify([:Honeybadger, :Utils])
      "Honeybadger.Utils"
  """
  def dotify(path) when is_list(path) do
    Enum.map_join(path, ".", &to_string/1)
  end

  @doc """
  Transform value into a consistently cased string representation

  # Example

      iex> Honeybadger.Utils.canonicalize(:User_SSN)
      "user_ssn"

  """
  def canonicalize(val) do
    val
    |> to_string()
    |> String.downcase()
  end

  def rand_id(size \\ 16) do
    size
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  @doc """
  Configurable data sanitization. This currently:

  - recursively truncates deep structures (to a depth of 20)
  - constrains large string values (to 64k)
  - filters out any map keys that might contain sensitive information.

  Options:
  - `:remove_filtered` - When `true`, filtered keys will be removed instead of replaced with "[FILTERED]". Default: `false`
  """
  @depth_token "[DEPTH]"
  @truncated_token "[TRUNCATED]"
  @filtered_token "[FILTERED]"

  # 64k with enough space to concat truncated_token
  @default_max_string_size 64 * 1024 - 11
  @default_max_depth 20

  def sanitize(value, opts \\ []) do
    base = %{
      max_depth: @default_max_depth,
      max_string_size: @default_max_string_size,
      filter_keys: Honeybadger.get_env(:filter_keys),
      remove_filtered: false
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

  defp sanitize_val(v, opts) when is_map(v) do
    %{depth: depth, filter_keys: filter_keys, remove_filtered: remove_filtered} = opts

    Enum.reduce(v, %{}, fn {key, val}, acc ->
      if MapSet.member?(filter_keys, canonicalize(key)) do
        if remove_filtered do
          # Skip this key entirely when remove_filtered is true
          acc
        else
          # Traditional behavior: replace with filtered token
          Map.put(acc, key, @filtered_token)
        end
      else
        Map.put(acc, key, sanitize_val(val, Map.put(opts, :depth, depth + 1)))
      end
    end)
  end

  defp sanitize_val(v, %{depth: depth} = opts) when is_list(v) do
    Enum.map(v, &sanitize_val(&1, Map.put(opts, :depth, depth + 1)))
  end

  defp sanitize_val(v, %{max_string_size: max_string_size}) when is_binary(v) do
    if String.valid?(v) and String.length(v) > max_string_size do
      String.slice(v, 0, max_string_size) <> @truncated_token
    else
      v
    end
  end

  defp sanitize_val(v, _), do: v
end
