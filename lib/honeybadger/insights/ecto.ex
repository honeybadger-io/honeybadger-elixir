defmodule Honeybadger.Insights.Ecto do
  @moduledoc """
  Captures database query telemetry events from Ecto repositories.

  ## Default Configuration

  By default, this module listens for telemetry events from all configured
  Ecto repositories. It reads the `:ecto_repos` configuration to identify
  repositories and their telemetry prefixes.

  ## Custom Configuration

  You can customize this module's behavior with the following configuration options:

      config :honeybadger, insights_config: %{
        ecto: %{
          # A list of strings or regex patterns of queries to exclude
          excluded_queries: [
            ~r/^(begin|commit)( immediate)?( transaction)?$/i,
            ~r/SELECT pg_notify/,
            ~r/schema_migrations/
          ],

          # Format & include the stacktrace with each query. You must also
          # update your repo config to enable:
          #
          #   config :my_app, MyApp.Repo,
          #     stacktrace: true
          #
          # Can be a boolean to enable for all or a list of sources to enable.
          include_stacktrace: true

          # Alternative source whitelist example:
          # include_stacktrace: ["source_a", "source_b"],

          # Format & include the query parameters with each query. Can be a
          # boolean to enable for all or a list of sources to enable.
          include_params: true

          # Alternative source whitelist example:
          # include_params:["source_a", "source_b"],

          # A list of table/source names to exclude
          excluded_sources: [
            "schema_migrations",
            "oban_jobs",
            "oban_peers"
          ]
        }
      }

  By default, transaction bookkeeping queries and schema migration checks are excluded,
  as well as queries to common background job tables.
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Ecto.Repo]
  @telemetry_events []

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
    |> include_stacktrace(meta)
    |> include_params(meta)
  end

  defp include_params(data, %{params: params, source: source}) do
    case get_insights_config(:include_params, false) do
      false ->
        data

      true ->
        Map.put(data, :params, params)

      sources when is_list(sources) ->
        if source in sources do
          Map.put(data, :params, params)
        else
          data
        end
    end
  end

  defp include_params(data, _), do: data

  defp include_stacktrace(data, %{stacktrace: stacktrace, source: source}) do
    case get_insights_config(:include_stacktrace, false) do
      false ->
        data

      true ->
        Map.put(data, :stacktrace, format_stacktrace(stacktrace))

      sources when is_list(sources) ->
        if source in sources do
          Map.put(data, :stacktrace, format_stacktrace(stacktrace))
        else
          data
        end
    end
  end

  defp include_stacktrace(data, _), do: data

  defp format_stacktrace(stacktrace) do
    Enum.map(stacktrace, &format_frame/1)
  end

  defp format_frame({module, function, arity, location}) do
    position =
      if is_list(location) and Keyword.has_key?(location, :file) do
        "#{location[:file]}:#{location[:line]}"
      else
        nil
      end

    [position, Exception.format_mfa(module, function, arity)]
  end

  def ignore?(%{query: query, source: source}) do
    if source in get_insights_config(:excluded_sources, @excluded_sources) do
      true
    else
      :excluded_queries
      |> get_insights_config(excluded_queries())
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

  defp escape_quotes(), do: ~r/(\\\"|\\')/
  defp squote_data(), do: ~r/'(?:[^']|'')*'/
  defp dquote_data(), do: ~r/"(?:[^"]|"")*"/
  defp number_data(), do: ~r/\b\d+\b/
  defp double_quoters(), do: ~r/(postgres|sqlite3|postgis)/i

  defp excluded_queries(),
    do: [
      ~r/^(begin|commit)( immediate)?( transaction)?$/i,
      # Also exclude pg_notify which is often used with Oban
      ~r/SELECT pg_notify/,
      ~r/schema_migrations/
    ]

  def obfuscate(sql, adapter) when is_binary(sql) do
    sql
    |> String.replace(~r/\s+/, " ")
    |> String.replace(escape_quotes(), "")
    |> String.replace(squote_data(), "'?'")
    |> maybe_replace_dquote(adapter)
    |> String.replace(number_data(), "?")
    |> String.trim()
  end

  defp maybe_replace_dquote(sql, adapter) do
    if Regex.match?(double_quoters(), to_string(adapter)) do
      sql
    else
      String.replace(sql, dquote_data(), "\"?\"")
    end
  end
end
