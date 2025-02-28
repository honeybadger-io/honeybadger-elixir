defmodule Honeybadger.Insights.Ecto do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Ecto.Repo]
  @telemetry_events []

  @excluded_queries [
    "begin",
    "commit",
    # Also exclude pg_notify which is often used with Oban
    ~r/SELECT pg_notify/,
    ~r/schema_migrations/
  ]

  @excluded_sources [
    "schema_migrations",
    "oban_jobs",
    "oban_peers"
  ]

  def get_telemetry_events do
    Honeybadger.get_env(:ecto_repos)
    |> Enum.map(&get_telemetry_prefix/1)
  end

  def extract_metadata(meta, _name) do
    Map.take(meta, [:query, :decode_time, :query_time, :queue_time, :source])
  end

  def ignore?(%{query: query, source: source}) do
    if source in get_insights_config(:excluded_sources, @excluded_sources) do
      true
    else
      get_insights_config(:excluded_queries, @excluded_queries)
      |> Enum.any?(fn pattern ->
        case pattern do
          pattern when is_binary(pattern) -> query == pattern
          %Regex{} -> Regex.match?(pattern, query)
          _ -> false
        end
      end)
    end
  end

  defp get_telemetry_prefix(repo) do
    case Keyword.get(repo.config(), :telemetry_prefix) do
      nil ->
        []

      telemetry_prefix ->
        telemetry_prefix ++ [:query]
    end
  end
end
