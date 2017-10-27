defmodule Honeybadger.Filter do
  @moduledoc """
  Specification of user overrideable filter functions.

  See moduledoc for `Honeybadger.Filter.Mixin` for details on implementing
  your own filter.
  """

  @doc """
  Filter the context Map.  The context is a map of application supplied data.
  """
  @callback filter_context(map) :: map

  @doc """
  For applications that use `Honeybadger.Plug`, filters the query parameters.
  The parameters is a map of `String.t` to `String.t`, e.g.:

      %{"user_name" => "fred", "password" => "12345"}
  """
  @callback filter_params(map) :: map

  @doc """
  For applications that use `Honeybadger.Plug`, filter the cgi_data.

  `cgi_data` is a map of `String.t` to `String.t` which includes HTTP headers
  and other pre-defined request data (including `PATH_INFO`, `QUERY_STRING`,
  `SERVER_PORT` etc.).
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
