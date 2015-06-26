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
          ArgumentError ->
            fetch_cookies conn
        end

        conn = fetch_query_params conn

        metadata = %{
          url: full_path(conn),
          component: get_component_from_module,
          action: "",
          params: conn.params,
          session: session,
          cgi_data: fetch_cgi_data(conn)
        }

        Honeybadger.notify reason, metadata
      end

      defp get_component_from_module do
        __MODULE__ 
        |> Atom.to_string
        |> String.split(".") 
        |> List.last
      end

      defp fetch_cgi_data(conn) do
        %{
          "REQUEST_METHOD" => conn.method,
          "PATH_INFO" => Enum.join(conn.path_info, "/"),
          "QUERY_STRING" => conn.query_string,
          "SCRIPT_NAME" => Enum.join(conn.script_name, "/"),
          "REMOTE_ADDR" => format_remote_addr(conn.remote_ip),
          "REMOTE_PORT" => format_remote_port(conn.peer),
          "SERVER_ADDR" => "127.0.0.1",
          "SERVER_NAME" => "localhost",
          "SERVER_PORT" => conn.port,
          "CONTENT_LENGTH" => get_req_header(conn, "content-length"),
          "HTTP_HOST" => conn.host,
          "HTTP_CONNECTION" => get_req_header(conn, "connection"),
          "HTTP_ACCEPT" => get_req_header(conn, "accept"),
          "HTTP_REFERER" => get_req_header(conn, "referer"),
          "HTTP_ACCEPT_ENCODING" => get_req_header(conn, "accept-encoding"),
          "HTTP_ACCEPT_LANGUAGE" => get_req_header(conn, "accept-language"),
          "HTTP_ACCEPT_CHARSET" => get_req_header(conn, "accept-charset"),
          "HTTP_COOKIE" => format_cookies(conn.req_cookies),
          "ORIGINAL_FULLPATH" => full_path(conn)
        }
      end

      defp format_cookies(cookies) do
        Enum.reduce cookies, "", fn ({key, val}, acc) ->
          acc <> "#{key}=#{val}"
        end
      end

      defp format_remote_addr(addr) do
        addr |> Tuple.to_list |> Enum.join(".")
      end

      defp format_remote_port({_, port}), do: port
    end
  end
end
