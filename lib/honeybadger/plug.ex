if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.Plug do
    alias Plug.Conn
    alias Honeybadger.{PhoenixData, PlugData}

    @doc false
    defmacro __using__(opts) do
      quote location: :keep do
        use Plug.ErrorHandler

        @ignored Keyword.get(unquote(opts), :ignore, [])

        @conn_data_mod if Code.ensure_loaded?(Phoenix), do: PhoenixData, else: PlugData

        for reason <- @ignored do
          def handle_errors(_conn, %{reason: reason}), do: nil
        end

        def handle_errors(conn, %{reason: reason, stack: stack}) do
          metadata = %{
            plug_env: build_plug_env(conn, __MODULE__),
            context: build_context(conn, __MODULE__)
          }

          Honeybadger.notify(reason, metadata, stack)
        end

        def build_plug_env(conn, module) do
          Honeybadger.Plug.build_plug_env(conn, module, @conn_data_mod)
        end

        def build_cgi_data(conn, _module) do
          Honeybadger.Plug.build_cgi_data(conn)
        end

        def build_context(conn, _module) do
          Honeybadger.context()
        end

        defoverridable build_cgi_data: 2,
                       build_plug_env: 2,
                       build_context: 2,
                       handle_errors: 2
      end
    end

    def build_plug_env(%Conn{} = conn, module, conn_data_mod) do
      conn = Conn.fetch_query_params(conn)

      %{
        action: conn_data_mod.action(conn),
        cgi_data: build_cgi_data(conn),
        component: conn_data_mod.component(conn, module),
        params: conn.params,
        session: %{},
        url: conn.request_path
      }
    end

    def build_cgi_data(%Conn{} = conn) do
      cgi_data = %{
        "REQUEST_METHOD" => conn.method,
        "PATH_INFO" => Enum.join(conn.path_info, "/"),
        "QUERY_STRING" => conn.query_string,
        "SCRIPT_NAME" => Enum.join(conn.script_name, "/"),
        "REMOTE_ADDR" => get_remote_addr(conn),
        "REMOTE_PORT" => get_remote_port(conn),
        "SERVER_ADDR" => "127.0.0.1",
        "SERVER_NAME" => Honeybadger.get_env(:hostname),
        "SERVER_PORT" => conn.port,
        "CONTENT_LENGTH" => Conn.get_req_header(conn, "content-length"),
        "ORIGINAL_FULLPATH" => conn.request_path
      }

      conn
      |> get_rack_format_headers()
      |> Map.merge(cgi_data)
    end

    # Helpers

    @doc false
    def get_rack_format_headers(%Conn{req_headers: req_headers}) do
      Enum.reduce(req_headers, %{}, fn {header, value}, acc ->
        header = ("HTTP_" <> String.upcase(header)) |> String.replace("-", "_")

        Map.put(acc, header, value)
      end)
    end

    @doc false
    def get_remote_addr(%Conn{remote_ip: remote_ip}) do
      remote_ip
      |> :inet.ntoa()
      |> List.to_string()
    end

    @doc false
    def get_remote_port(%Conn{peer: {_, port}}), do: port
  end
end
