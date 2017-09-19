defmodule Honeybadger.Filter do
  @moduledoc """
    Specification of user overrideable filter functions.

    See moduledoc for `Honeybadger.FilterMixin` for details on
    implementing your own filter.
  """

  @doc """
    Filter the context Map.  The context is a map of application supplied
    data.
  """
  @callback filter_context(map) :: map

  @doc """
    For applications that use `Honeybadger.Plug`, filters the query
    parameters. The parameters is a map of `String.t` to `String.t`, e.g.:
        %{"user_name" => "fred", "password" => "12345"}
  """
  @callback filter_params(map) :: map

  @doc """
    For applications that use `Honeybadger.Plug`, filter the cgi_data.
    `cgi_data` is a map of `String.t` to `String.t` which includes HTTP
    headers and other pre-defined request data (including `PATH_INFO`,
    `QUERY_STRING`, `SERVER_PORT` etc.).
  """
  @callback filter_cgi_data(map) :: map

  @doc """
    For applications that use `Honeybadger.Plug`, filter the session.
  """
  @callback filter_session(map) :: map


  @doc """
    Filter the error message string.  This is the message from the most
    recently thrown error.
  """
  @callback filter_error_message(String.t) :: String.t
end

defmodule Honeybadger.NoticeFilter do
  @moduledoc """
    Specification for a top level Honeybadger.Notice filter.

    Most users won't need this, but if you need complete control over
    filtering, implement this behaviour and configure like:

        config :honeybadger,
          notice_filter: MyApp.MyNoticeFilter
  """
  @callback filter(Honeybadger.Notice.t) :: Honeybadger.Notice.t
end

defmodule Honeybadger.FilterMixin do
  @moduledoc """
    A default implementation of `Honeybadger.Filter`.

    If you need to implement custom filtering for one or more of the
    elements in a `Honeybadger.Notice`, you can define your own filter
    module and register it in the config.  E.g., if you wanted to filter
    the error message string, but keep all of the other default filtering,
    you could do:
        defmoudle MyApp.MyFilter do
          use Honeybadger.FilterMixin

          def filter_error_message(message) do
            # replace passwords in error message with `"xxx"`
            Regex.replace(~r/(password:\s*)"([^"]+)"/, message, ~s(\\1"xxx"))
          end
        end

    And set the configuration to:
        config :honeybadger,
          filter: MyApp.MyFilter

    See the documentation for `Honeybadger.Filter` for a list of functions
    that may be overridden.  The default implementations for all of the
    functions that take a `map` are to remove any keys from the map that
    match a key in `filter_keys`.  The check matches atoms and strings in a
    case insensitive manner.
  """
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Honeybadger.Filter

      def filter_context(context), do: filter_map(context)
      def filter_params(params), do: filter_map(params)
      def filter_cgi_data(cgi_data), do: filter_map(cgi_data)
      def filter_session(session), do: filter_map(session)
      def filter_error_message(message), do: message

      defp filter_map(map) do
        case Honeybadger.get_env(:filter_keys) do
          keys when is_list(keys) ->
            filter_keys = Enum.map(keys, &canonicalize(&1))
            drop_keys = Enum.filter(Map.keys(map),
              &Enum.member?(filter_keys, canonicalize(&1)))
            Map.drop(map, drop_keys)
          _ -> map
        end
      end

      defp canonicalize(key), do: key |> to_string |> String.downcase

      defoverridable [filter_context: 1, filter_params: 1, filter_cgi_data: 1,
                      filter_session: 1, filter_error_message: 1]
    end
  end
end

defmodule Honeybadger.DefaultNoticeFilter do
  @behaviour Honeybadger.NoticeFilter

  def filter(%Honeybadger.Notice{} = notice) do
    if filter = Honeybadger.get_env(:filter) do
      notice
      |> Map.put(:request, filter_request(notice.request, filter))
      |> Map.put(:error, filter_error(notice.error, filter))
    else
      notice
    end
  end

  defp filter_request(request, filter) do
    request
    |> apply_filter(:context, &filter.filter_context/1)
    |> apply_filter(:params, &filter.filter_params/1)
    |> apply_filter(:cgi_data, &filter.filter_cgi_data/1)
    |> apply_filter(:session, &filter.filter_session/1)
    |> disable(:filter_disable_url, :url)
    |> disable(:filter_disable_session, :session)
    |> disable(:filter_disable_params, :params)
  end

  defp apply_filter(request, key, filter_fn) do
    case request |> Map.get(key) do
      nil -> request
      target -> Map.put(request, key, filter_fn.(target))
    end
  end

  defp filter_error(%{message: message} = error, filter) do
    error
    |> Map.put(:message, filter.filter_error_message(message))
  end

  defp disable(request, config_key, map_key) do
    if Honeybadger.get_env(config_key) do
      request |> Map.drop([map_key])
    else
      request
    end
  end
end

defmodule Honeybadger.DefaultFilter do
  use Honeybadger.FilterMixin
  @moduledoc """
    The default implementation for the `filter` configuration.  Removes
    keys listed in `filter_keys` from maps and respects the
    `filter_disable_*` configuration values.
  """
end
