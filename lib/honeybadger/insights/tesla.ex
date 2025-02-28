defmodule Honeybadger.Insights.Tesla do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Tesla]

  @telemetry_events [
    "tesla.request.stop",
    "tesla.request.exception"
  ]

  def extract_metadata(meta, _name) do
    env = Map.get(meta, :env, %{})

    %{
      method: env.method |> to_string() |> String.upcase(),
      url: env.url,
      status_code: env.status
    }
  end
end
