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

      def filter_map(map, keys) when is_list(keys) do
        filter_keys = Enum.map(keys, &Honeybadger.Utils.canonicalize/1)

        drop_keys =
          map
          |> Map.keys()
          |> Enum.filter(&Enum.member?(filter_keys, Honeybadger.Utils.canonicalize(&1)))

        Map.drop(map, drop_keys)
      end

      def filter_map(map, _keys) do
        map
      end

      defoverridable Honeybadger.Filter
    end
  end
end
