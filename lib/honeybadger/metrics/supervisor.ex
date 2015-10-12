defmodule Honeybadger.Metrics.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    child = worker(Honeybadger.Metrics.Server, [])
    supervise([child], strategy: :one_for_one)
  end

end
