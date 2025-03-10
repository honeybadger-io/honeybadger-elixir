defmodule Honeybadger.Insights.Ecto do
  @moduledoc false

  use Honeybadger.Insights.Base

  @required_dependencies [Ecto.Repo]
  @telemetry_events []

  @excluded_queries [
    ~r/^(begin|commit)( immediate)?( transaction)?$/i,
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
    :ecto_repos
    |> Honeybadger.get_env()
    |> Enum.map(&get_telemetry_prefix/1)
  end

  def extract_metadata(meta, _name) do
    meta
    |> Map.take([:query, :decode_time, :query_time, :queue_time, :source])
    |> Map.update!(:query, &obfuscate(&1, meta.repo.__adapter__()))
  end

  def ignore?(%{query: query, source: source}) do
    if source in get_insights_config(:excluded_sources, @excluded_sources) do
      true
    else
      :excluded_queries
      |> get_insights_config(@excluded_queries)
      |> Enum.any?(fn
        pattern when is_binary(pattern) -> query == pattern
        %Regex{} = pattern -> Regex.match?(pattern, query)
        _pattern -> false
      end)
    end
  end

  defp get_telemetry_prefix(repo) do
    Keyword.get(repo.config(), :telemetry_prefix, []) ++ [:query]
  end

  @escape_quotes ~r/(\\\"|\\')/
  @squote_data ~r/'(?:[^']|'')*'/
  @dquote_data ~r/"(?:[^"]|"")*"/
  @number_data ~r/\b\d+\b/
  @double_quoters ~r/(postgres|sqlite3|postgis)/i

  def obfuscate(sql, adapter) when is_binary(sql) do
    sql
    |> String.replace(~r/\s+/, " ")
    |> String.replace(@escape_quotes, "")
    |> String.replace(@squote_data, "'?'")
    |> maybe_replace_dquote(adapter)
    |> String.replace(@number_data, "?")
    |> String.trim()
  end

  defp maybe_replace_dquote(sql, adapter) do
    if Regex.match?(@double_quoters, to_string(adapter)) do
      sql
    else
      String.replace(sql, @dquote_data, "\"?\"")
    end
  end
end
