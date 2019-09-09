defmodule Honeybadger.Breadcrumbs.Telemetry do
  @moduledoc false

  def attach do
    :telemetry.attach(
      "hb-phoenix-router-dispatch",
      [:phoenix, :router_dispatch, :start],
      &handle_telemetry/4,
      nil
    )
  end

  def handle_telemetry([:phoenix, :router_dispatch, :start], _, meta, _data) do
    metadata =
      meta
      |> Map.take([:plug, :plug_opts, :route, :pipe_through])
      |> Map.update(:pipe_through, "", &inspect/1)

    Honeybadger.add_breadcrumb("Phoenix Router Dispatch",
      metadata: metadata,
      category: "request"
    )
  end
end
