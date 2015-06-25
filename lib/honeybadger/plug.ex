defmodule Honeybadger.Plug do
  defmacro __using__(_env) do
    quote do
      import Plug.Conn
      use Plug.ErrorHandler

      defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
        conn = try do
          fetch_session conn
          session = conn.session
          conn
        rescue
          ArgumentError ->
            fetch_cookies conn
        end

        conn = fetch_query_params conn
        cookies = conn.cookies
        component = get_component_from_module
        params = conn.params
        url = full_path conn
      end

      defp get_component_from_module do
        __MODULE__ 
        |> Atom.to_string
        |> String.split(".") 
        |> List.last
      end
    end
  end
end
