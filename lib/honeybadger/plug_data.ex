if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.PlugData do
    @moduledoc false

    @behaviour Honeybadger.EndpointData

    alias Honeybadger.{EndpointData, Utils}

    @impl EndpointData
    def component(_conn, mod), do: Utils.module_to_string(mod)

    @impl EndpointData
    def action(_conn), do: ""
  end
end
