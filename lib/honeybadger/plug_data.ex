if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.PlugData do
    @moduledoc false

    alias Plug.Conn

    @type plug_env :: %{
            action: binary(),
            cgi_data: map(),
            component: binary(),
            params: map(),
            session: map(),
            url: binary()
          }

    @type metadata :: %{
            context: any(),
            plug_env: plug_env()
          }

    @doc """
    Generate notification metadata from a `Plug.Conn`.

    The map that is returned contains the current context and environmental
    data.
    """
    @spec metadata(Conn.t(), module()) :: metadata()
    def metadata(conn, module) do
      %{context: Honeybadger.context(), plug_env: build_plug_env(conn, module)}
    end

    @doc false
    @spec build_plug_env(Conn.t(), module()) :: plug_env()
    def build_plug_env(%Conn{} = conn, module) do
      conn = Conn.fetch_query_params(conn)

      %{
        params: conn.params,
        session: %{},
        url: conn.request_path,
        action: action(conn),
        component: component(conn, module),
        cgi_data: build_cgi_data(conn)
      }
    end

    @doc false
    @spec build_cgi_data(Conn.t()) :: map()
    def build_cgi_data(%Conn{} = conn) do
      cgi_data = %{
        "REQUEST_METHOD" => conn.method,
        "PATH_INFO" => Enum.join(conn.path_info, "/"),
        "QUERY_STRING" => conn.query_string,
        "SCRIPT_NAME" => Enum.join(conn.script_name, "/"),
        "REMOTE_ADDR" => remote_addr(conn),
        "REMOTE_PORT" => remote_port(conn),
        "SERVER_ADDR" => "127.0.0.1",
        "SERVER_NAME" => Honeybadger.get_env(:hostname),
        "SERVER_PORT" => conn.port,
        "CONTENT_LENGTH" => Conn.get_req_header(conn, "content-length"),
        "ORIGINAL_FULLPATH" => conn.request_path
      }

      headers = rack_format_headers(conn)

      Map.merge(cgi_data, headers)
    end

    # Helpers

    defp component(%Conn{private: private}, module) do
      import Honeybadger.Utils, only: [module_to_string: 1]

      case private do
        %{phoenix_controller: controller} -> module_to_string(controller)
        _ -> module_to_string(module)
      end
    end

    defp action(%Conn{private: private}) do
      case private do
        %{phoenix_action: action_name} -> to_string(action_name)
        _ -> ""
      end
    end

    defp rack_format_headers(%Conn{req_headers: req_headers}) do
      Enum.reduce(req_headers, %{}, fn {header, value}, acc ->
        header = ("HTTP_" <> String.upcase(header)) |> String.replace("-", "_")

        Map.put(acc, header, value)
      end)
    end

    defp remote_addr(%Conn{remote_ip: remote_ip}) do
      remote_ip
      |> :inet.ntoa()
      |> List.to_string()
    end

    defp remote_port(conn) do
      cond do
        function_exported?(Conn, :get_peer_data, 1) ->
          conn
          |> Conn.get_peer_data()
          |> Map.get(:port)

        Map.has_key?(conn, :peer) ->
          conn
          |> Map.get(:peer)
          |> elem(1)

        true ->
          nil
      end
    end
  end
end
