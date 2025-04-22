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

  test "start_link returns :ignore if rate is 1.0" do
    assert :ignore == start_sampler()
  end

  test "returns true immediately if sample rate is 1" do
    assert EventsSampler.sample?(:foo, nil)
    assert EventsSampler.sample?(nil, nil)
  end

  test "samples for hashed values" do
    with_config([insights_sample_rate: 0.5], fn ->
      {:ok, sampler} = start_sampler(sampled_log_interval: 200)

      log =
        capture_log(fn ->
          EventsSampler.sample?("trace-1", sampler)
          EventsSampler.sample?("trace-2", sampler)
          Process.sleep(500)
        end)

      assert log =~ ~r/\[Honeybadger\] Sampled \d events \(of 2 total events\)/
    end)
  end

  test "samples for nil hash values" do
    with_config([insights_sample_rate: 0.5], fn ->
      {:ok, sampler} = start_sampler(sampled_log_interval: 200)

      log =
        capture_log(fn ->
          EventsSampler.sample?(nil, sampler)
          EventsSampler.sample?(nil, sampler)
          EventsSampler.sample?(nil, sampler)
          Process.sleep(500)
        end)

      assert log =~ ~r/\[Honeybadger\] Sampled \d events \(of 3 total events\)/
    end)
  end
end
