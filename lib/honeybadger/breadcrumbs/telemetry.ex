defmodule Honeybadger.Breadcrumbs.Telemetry do
  @moduledoc false

  @spec telemetry_events() :: [[atom()]]
  def telemetry_events do
    []
    |> append_phoenix_events()
    |> append_ecto_events()
  end

  @spec attach() :: :ok
  def attach do
    :telemetry.attach_many(
      "hb-telemetry",
      telemetry_events(),
      &handle_telemetry/4,
      nil
    )

    :ok
  end

  @spec append_phoenix_events([[atom()]]) :: [[atom()]]
  defp append_phoenix_events(events) do
    Enum.concat(
      events,
      [[:phoenix, :router_dispatch, :start]]
    )
  end

  @spec append_ecto_events([[atom()]]) :: [[atom()]]
  defp append_ecto_events(events) do
    case Honeybadger.get_env(:ecto_repos) do
      repos ->
        repos
        |> Enum.map(&get_telemetry_prefix/1)
        |> Enum.concat(events)

      _ ->
        events
    end
  end

  @spec get_telemetry_prefix(Ecto.Repo.t()) :: [atom()]
  defp get_telemetry_prefix(repo) do
    case Keyword.get(repo.config(), :telemetry_prefix) do
      nil ->
        []

      telemetry_prefix ->
        telemetry_prefix ++ [:query]
    end
  end

  def handle_telemetry(_path, %{decode_time: _} = time, %{query: _} = meta, _) do
    Map.merge(time, meta)
    |> handle_sql()
  end

  def handle_telemetry(_path, _time, %{query: _} = meta, _) do
    handle_sql(meta)
  end

  def handle_telemetry([:phoenix, :router_dispatch, :start], _timing, meta, _) do
    metadata =
      meta
      |> Map.take([:plug, :plug_opts, :route, :pipe_through])
      |> Map.update(:pipe_through, "", &inspect/1)

    Honeybadger.add_breadcrumb("Phoenix Router Dispatch",
      metadata: metadata,
      category: "request"
    )
  end

  defp handle_sql(meta) do
    metadata =
      meta
      |> Map.take([:query, :decode_time, :query_time, :queue_time, :source])
      |> Map.update(:decode_time, nil, &time_format/1)
      |> Map.update(:query_time, nil, &time_format/1)
      |> Map.update(:queue_time, nil, &time_format/1)

    Honeybadger.add_breadcrumb("Ecto SQL Query (#{meta[:source]})",
      metadata: metadata,
      category: "query"
    )
  end

  defp time_format(nil), do: nil

  defp time_format(time) do
    us = System.convert_time_unit(time, :native, :microsecond)
    ms = div(us, 100) / 10
    "#{:io_lib_format.fwrite_g(ms)}ms"
  end
end
