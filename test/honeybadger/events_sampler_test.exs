defmodule Honeybadger.EventsSamplerTest do
  use Honeybadger.Case, async: true
  require Logger

  alias Honeybadger.EventsSampler

  defp start_sampler(config \\ []) do
    name =
      "test_events_sampler_#{System.unique_integer([:positive])}"
      |> String.to_atom()

    EventsSampler.start_link(config ++ [name: name])
  end

  test "returns true immediately if default sample rate is 100" do
    assert EventsSampler.sample?(hash_value: :foo)
    assert EventsSampler.sample?()
  end

  test "returns true immediately if passed in sample rate is 100" do
    with_config([insights_sample_rate: 0], fn ->
      assert EventsSampler.sample?(sample_rate: 100)
    end)
  end

  test "samples for hashed values" do
    with_config([insights_sample_rate: 50], fn ->
      {:ok, sampler} = start_sampler(sampled_log_interval: 100)

      log =
        capture_log(fn ->
          EventsSampler.sample?(hash_value: "trace-1", server: sampler)
          EventsSampler.sample?(hash_value: "trace-2", server: sampler)
          Process.sleep(500)
        end)

      assert log =~ ~r/\[Honeybadger\] Sampled \d events \(of 2 total events\)/
    end)
  end

  test "samples for un-hashed values" do
    with_config([insights_sample_rate: 50], fn ->
      {:ok, sampler} = start_sampler(sampled_log_interval: 100)

      log =
        capture_log(fn ->
          EventsSampler.sample?(server: sampler)
          EventsSampler.sample?(server: sampler)
          EventsSampler.sample?(server: sampler)
          Process.sleep(500)
        end)

      assert log =~ ~r/\[Honeybadger\] Sampled \d events \(of 3 total events\)/
    end)
  end

  test "respects custom sample rate in opts" do
    with_config([insights_sample_rate: 50], fn ->
      {:ok, sampler} = start_sampler()

      # Force sampling to occur with 100% sample rate
      assert EventsSampler.sample?(hash_value: "trace-1", sample_rate: 100, server: sampler)

      # Force sampling to not occur with 0% sample rate
      refute EventsSampler.sample?(hash_value: "trace-1", sample_rate: 0, server: sampler)
    end)
  end
end
