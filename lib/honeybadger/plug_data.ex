if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.PlugData do
    alias Honeybadger.Utils

    def component(_conn, mod), do: Utils.module_to_string(mod)
    def action(_conn), do: ""
  end
end
