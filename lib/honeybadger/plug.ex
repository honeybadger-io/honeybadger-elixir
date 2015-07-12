defmodule Honeybadger.Plug do
  defmacro __using__(_env) do
    quote do
      import Plug.Conn
      use Plug.ErrorHandler

      defp handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
        session = %{}
        conn = try do
          fetch_session conn
          session = conn.session
          conn
        rescue
          e in [ArgumentError, KeyError] ->
            fetch_cookies conn
        end

        conn = fetch_query_params conn

        metadata = %{
          url: full_path(conn),
          component: get_component_from_module,
          action: "",
          params: conn.params,
          session: session,
          cgi_data: build_cgi_data(conn)
        }

        Honeybadger.notify reason, %{plug_env: metadata}, stack
      end

      defp get_component_from_module do
        __MODULE__ 
        |> Atom.to_string
        |> String.split(".") 
        |> List.last
      end

      defp build_cgi_data(%Plug.Conn{} = conn) do
        rack_env_http_vars = Enum.reduce conn.req_headers, %{}, &header_to_rack_format/2
        cgi_data = %{
          "REQUEST_METHOD" => conn.method,
          "PATH_INFO" => Enum.join(conn.path_info, "/"),
          "QUERY_STRING" => conn.query_string,
          "SCRIPT_NAME" => Enum.join(conn.script_name, "/"),
          "REMOTE_ADDR" => get_remote_addr(conn.remote_ip),
          "REMOTE_PORT" => get_remote_port(conn.peer),
          "SERVER_ADDR" => "127.0.0.1",
          "SERVER_NAME" => Application.get_env(:honeybadger, :hostname),
          "SERVER_PORT" => conn.port,
          "CONTENT_LENGTH" => get_req_header(conn, "content-length"),
          "ORIGINAL_FULLPATH" => full_path(conn)
        } 

        Map.merge rack_env_http_vars, cgi_data
      end

      defp get_remote_addr(addr), do: :inet.ntoa(addr) |> List.to_string
      defp get_remote_port({_, port}), do: port

      defp header_to_rack_format({header, value}, acc) do
        header = "HTTP_" <> String.upcase(header) |> String.replace("-", "_")
        Map.put acc, header, value
      end
    end
  end
end
