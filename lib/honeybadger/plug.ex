if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.Plug do
    defmacro __using__(opts) do
      quote do
        use Plug.ErrorHandler

        import Honeybadger.Plug

        @phoenix Keyword.get(unquote(opts), :phoenix, :code.is_loaded(Phoenix))

        # Exceptions raised on non-existent Plug routes are ignored
        def handle_errors(conn, %{reason: %FunctionClauseError{function: :do_match}} = ex) do
          nil
        end

        if @phoenix do
          # Exceptions raised on non-existent Phoenix routes are ignored
          def handle_errors(conn, %{reason: %Phoenix.Router.NoRouteError{}} = ex) do
            nil
          end
        end

        def handle_errors(conn, %{kind: _kind, reason: exception, stack: stack}) do
          metadata = %{plug_env: build_plug_env(conn, __MODULE__, @phoenix),
                       context: Honeybadger.context()}
          Honeybadger.notify(exception, metadata, stack)
        end

        defoverridable [handle_errors: 2]
      end
    end

    def build_plug_env(%Plug.Conn{} = conn, mod, phoenix \\ false) do
      {conn, session} = try do
        Plug.Conn.fetch_session(conn)
        session = conn.session
        {conn, session}
      rescue
        _e in [ArgumentError, KeyError] ->
          # just return conn and move on
          {conn, %{}}
      end

      conn = conn
             |> Plug.Conn.fetch_cookies
             |> Plug.Conn.fetch_query_params

      conn_data_mod = if phoenix do
        Honeybadger.PhoenixData
      else
        Honeybadger.PlugData
      end

      %{url: conn.request_path,
        component: conn_data_mod.component(conn, mod),
        action: conn_data_mod.action(conn),
        params: conn.params,
        session: session,
        cgi_data: build_cgi_data(conn)}
    end

    def build_cgi_data(%Plug.Conn{} = conn) do
      rack_env_http_vars = Enum.reduce conn.req_headers, %{}, &header_to_rack_format/2
      cgi_data = %{
        "REQUEST_METHOD" => conn.method,
        "PATH_INFO" => Enum.join(conn.path_info, "/"),
        "QUERY_STRING" => conn.query_string,
        "SCRIPT_NAME" => Enum.join(conn.script_name, "/"),
        "REMOTE_ADDR" => get_remote_addr(conn.remote_ip),
        "REMOTE_PORT" => get_remote_port(conn.peer),
        "SERVER_ADDR" => "127.0.0.1",
        "SERVER_NAME" => Honeybadger.get_env(:hostname),
        "SERVER_PORT" => conn.port,
        "CONTENT_LENGTH" => Plug.Conn.get_req_header(conn, "content-length"),
        "ORIGINAL_FULLPATH" => conn.request_path
      }

      Map.merge(rack_env_http_vars, cgi_data)
    end

    def get_remote_addr(addr), do: :inet.ntoa(addr) |> List.to_string
    def get_remote_port({_, port}), do: port

    def header_to_rack_format({header, value}, acc) do
      header = "HTTP_" <> String.upcase(header) |> String.replace("-", "_")
      Map.put(acc, header, value)
    end
  end
end
