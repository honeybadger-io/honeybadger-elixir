defmodule Honeybadger.Metrics.Server do
  use GenServer
  alias Honeybadger.Metric
  alias Honeybadger.Client

  @moduledoc """
    This GenServer receives metrics (the response time) from
    the Honeybadger Plug. Every 60 seconds this GenServer will
    message itself to flush the list of response times to the
    Honeybadger metrics API.
  """

  @one_minute 60_000

  def start_link(flush_interval \\ @one_minute, name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, flush_interval, name: name)
  end

  ## API

  def timing(time) do
    GenServer.cast(__MODULE__, {:add_timing, time})
  end

  ## GenServer Callbacks

  def init(flush_interval) do
    schedule_flush_message(flush_interval)
    {:ok, %{timings: [], interval: flush_interval}}
  end

  def handle_cast({:add_timing, time}, state) do
    {_, state} = Map.get_and_update(state, :timings, fn(timings) ->
      {timings, [time | timings]}

    end)
    {:noreply, state}
  end

  def handle_info(:flush, %{timings: []} = state) do
    schedule_flush_message(state[:interval])
    {:noreply, state}
  end

  def handle_info(:flush, state) do
    schedule_flush_message(state[:interval])
    client = Client.new
    metric = Metric.new(state[:timings])
    Client.send_metric(client, metric, HTTPoison)
    {:noreply, Map.put(state, :timings, [])}
  end

  ## Private API

  defp schedule_flush_message(flush_interval) do
    Process.send_after(self(), :flush, flush_interval)
  end
end
