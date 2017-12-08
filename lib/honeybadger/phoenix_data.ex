if Code.ensure_loaded?(Phoenix) do
  defmodule Honeybadger.PhoenixData do
    alias Honeybadger.Utils

    def component(conn, mod) do
      # Phoenix.Controller.controller_module unfortunately raises
      # when phoenix controller isn't available
      case Utils.safe_exec(fn -> Phoenix.Controller.controller_module(conn) end) do
        {:ok, controller} ->
          Utils.module_to_string(controller)
        {:error, _err} ->
          Utils.module_to_string(mod)
      end
    end

    def action(conn) do
      # Phoenix.Controller.action_module unfortunately raises
      # when phoenix controller isn't available
      case Utils.safe_exec(fn -> Phoenix.Controller.action_name(conn) end) do
        {:ok, action_name} ->
          to_string(action_name)
        {:error, _err} ->
          ""
      end
    end
  end
end
