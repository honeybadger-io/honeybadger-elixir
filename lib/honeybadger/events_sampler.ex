defmodule Honeybadger.EventsSampler do
  @moduledoc false

  use GenServer
  require Logger

  # Every 5 minutes, we log the number of sampled events
  @sampled_log_interval 5 * 60 * 1000
  @hash_max 1_000_000
  @fully_sampled_rate 100

  def start_link(opts \\ []) do
    if Honeybadger.get_env(:insights_sample_rate) == @fully_sampled_rate do
      :ignore
    else
      {name, opts} = Keyword.pop(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(opts) do
    state =
      %{
        sample_rate: Honeybadger.get_env(:insights_sample_rate),
        sampled_log_interval: @sampled_log_interval,
        sample_count: 0,
        ignore_count: 0
      }
      |> Map.merge(Map.new(opts))

    schedule_report(state.sampled_log_interval)

    {:ok, state}
  end

  def sample?(hash_value \\ nil, server \\ __MODULE__) do
    if Honeybadger.get_env(:insights_sample_rate) == @fully_sampled_rate do
      true
    else
      GenServer.call(server, {:sample?, hash_value})
    end
  end

  @impl true
  def handle_call({:sample?, hash_value}, _from, state) do
    decision = do_sample?(hash_value, state.sample_rate)
    # Increment the count of sampled or ignored events
    count_key = if decision, do: :sample_count, else: :ignore_count
    state = update_in(state, [count_key], &(&1 + 1))
    {:reply, decision, state}
  end

  @impl true
  def handle_info(:report, %{sample_count: sample_count, ignore_count: ignore_count} = state) do
    if sample_count > 0 do
      Logger.debug(
        "[Honeybadger] Sampled #{sample_count} events (of #{sample_count + ignore_count} total events)"
      )
    end

    schedule_report(state.sampled_log_interval)

    {:noreply, %{state | sample_count: 0, ignore_count: 0}}
  end

  # Use random sampling when no hash value is provided
  defp do_sample?(nil, sample_rate) do
    :rand.uniform() * @fully_sampled_rate < sample_rate
  end

  # Use hash sampling when a hash value is provided
  defp do_sample?(hash_value, sample_rate) when is_binary(hash_value) or is_atom(hash_value) do
    :erlang.phash2(hash_value, @hash_max) / @hash_max * @fully_sampled_rate < sample_rate
  end

  defp schedule_report(interval) do
    Process.send_after(self(), :report, interval)
  end
end
