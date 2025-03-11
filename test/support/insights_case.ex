defmodule Honeybadger.InsightsCase do
  @moduledoc """
  This module defines helpers for testing
  Honeybadger.Insights instrumentation.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import helpers from this module
      import Honeybadger.InsightsCase

      setup do
        {:ok, _} = Honeybadger.API.start(self())

        restart_with_config(
          insights_enabled: true,
          exclude_envs: []
        )

        on_exit(fn ->
          Honeybadger.API.stop()
        end)

        :ok
      end
    end
  end

  @doc """
  Sends a telemetry event and waits to receive the resulting API request.
  Returns the event data from the request.
  """
  def send_and_receive(event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
    assert_receive {:api_request, request}
    request
  end
end
