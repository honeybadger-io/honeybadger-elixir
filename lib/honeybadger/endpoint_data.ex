if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.EndpointData do
    @moduledoc """
    The HandlerData specification, used by any module that will report request
    handling details.
    """

    @doc """
    Extract the name of the handling component.

    This could be a controller for a Phoenix application, or a module in a plug
    pipeline.
    """
    @callback component(Plug.Conn.t(), module()) :: binary()

    @doc """
    Extract the named action for the handling component.

    This could be a function like `create` or `update` in a Phoenix application.
    """
    @callback action(Plug.Conn.t()) :: binary()
  end
end
