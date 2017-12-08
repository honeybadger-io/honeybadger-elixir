if Code.ensure_loaded?(Phoenix) do
  defmodule Honeybadger.PhoenixData do
    @moduledoc false

    @behaviour Honeybadger.EndpointData

    alias Honeybadger.{EndpointData, Utils}

    @impl EndpointData
    def component(conn, mod) do
      case Utils.safe_exec(fn -> Phoenix.Controller.controller_module(conn) end) do
        {:ok, controller} ->
          Utils.module_to_string(controller)
        {:error, _err} ->
          Utils.module_to_string(mod)
      end
    end

    @impl EndpointData
    def action(conn) do
      case Utils.safe_exec(fn -> Phoenix.Controller.action_name(conn) end) do
        {:ok, action_name} ->
          to_string(action_name)
        {:error, _err} ->
          ""
      end
    end
  end
end
