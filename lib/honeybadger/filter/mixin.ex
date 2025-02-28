defmodule Honeybadger.Filter.Mixin do
  @moduledoc """
  A default implementation of `Honeybadger.Filter`.

  If you need to implement custom filtering for one or more of the elements in
  a `Honeybadger.Notice`, you can define your own filter module and register it
  in the config.  E.g., if you wanted to filter the error message string, but
  keep all of the other default filtering, you could do:

      defmodule MyApp.MyFilter do
        use Honeybadger.Filter.Mixin

        def filter_error_message(message) do
          # replace passwords in error message with `"xxx"`
          Regex.replace(~r/(password:\s*)"([^"]+)"/, message, ~s(\\1"xxx"))
        end
      end

  And set the configuration to:

      config :honeybadger,
        filter: MyApp.MyFilter

  See the documentation for `Honeybadger.Filter` for a list of functions that
  may be overridden.  The default implementations for all of the functions that
  take a `map` are to remove any keys from the map that match a key in
  `filter_keys`. The check matches atoms and strings in a case insensitive
  manner.
  """
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Honeybadger.Filter

      def filter_context(context), do: filter_map(context)
      def filter_params(params), do: filter_map(params)
      def filter_cgi_data(cgi_data), do: filter_map(cgi_data)
      def filter_session(session), do: filter_map(session)
      def filter_error_message(message), do: message
      def filter_breadcrumbs(breadcrumbs), do: breadcrumbs

      @doc false
      def filter_map(map) do
        filter_map(map, Honeybadger.get_env(:filter_keys))
      end

      def filter_map(map, keys) when is_map(map) and is_list(keys) do
        # Pre-canonicalize filter keys once
        filter_keys = MapSet.new(keys, &Honeybadger.Utils.canonicalize/1)

        # Use recursion to process the map
        do_filter_map(map, filter_keys)
      end

      def filter_map(value, _keys), do: value

      # Convert struct to map, filter it, then convert back to the same struct type
      defp do_filter_map(%{__struct__: struct_type} = struct, filter_keys) do
        struct
        |> Map.from_struct()
        |> do_filter_map(filter_keys)
        |> then(fn filtered_map -> struct(struct_type, filtered_map) end)
      end

      # Handle maps recursively
      defp do_filter_map(map, filter_keys) when is_map(map) do
        Enum.reduce(map, %{}, fn {key, value}, acc ->
          if MapSet.member?(filter_keys, Honeybadger.Utils.canonicalize(key)) do
            acc
          else
            Map.put(acc, key, do_filter_map(value, filter_keys))
          end
        end)
      end

      # Handle lists by mapping over each element
      defp do_filter_map(list, filter_keys) when is_list(list) do
        Enum.map(list, &do_filter_map(&1, filter_keys))
      end

      # Handle all other data types by returning them as-is
      defp do_filter_map(value, _filter_keys), do: value

      defoverridable Honeybadger.Filter
    end
  end
end
