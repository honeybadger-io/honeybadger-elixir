defmodule ErrorServer do
  use GenServer

  def start do
    GenServer.start(__MODULE__, [])
  end

  def init(_), do: {:ok, []}

  def handle_cast(:fail, _from, _state) do
    raise RuntimeError, "Crashing"
  end
end
