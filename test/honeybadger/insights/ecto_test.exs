defmodule Honeybadger.Insights.EctoTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  alias Honeybadger.Insights

  defmodule Ecto.Repo do
  end

  defmodule Adapter.Postgres do
  end

  defmodule Test.MockEctoConfig do
    def config() do
      [telemetry_prefix: [:a, :b]]
    end
  end

  setup do
    restart_with_config(ecto_repos: [Test.MockEctoConfig])
  end

  describe "Ecto instrumentation" do
    test "extracts metadata from query event" do
      event =
        send_and_receive(
          [:a, :b, :query],
          %{
            total_time: System.convert_time_unit(25, :millisecond, :native),
            decode_time: System.convert_time_unit(5, :millisecond, :native),
            query_time: System.convert_time_unit(15, :millisecond, :native),
            queue_time: System.convert_time_unit(5, :millisecond, :native)
          },
          %{
            query: "SELECT u0.id, u0.name FROM users u0 WHERE u0.id = ?",
            source: "users",
            repo: %{__adapter__: Adapter.Postgres}
          }
        )

      assert event["query"] =~ "SELECT u0.id, u0.name FROM users u0 WHERE u0.id = ?"
      assert event["source"] == "users"
      assert event["total_time"] == 25
      assert event["decode_time"] == 5
      assert event["query_time"] == 15
      assert event["queue_time"] == 5
    end

    test "ignores excluded sources" do
      with_config([insights_config: %{ecto: %{excluded_sources: ["users"]}}], fn ->
        :telemetry.execute(
          [:a, :b, :query],
          %{},
          %{
            query: "SELECT u0.id, u0.name FROM users u0 WHERE u0.id = ?",
            source: "users",
            repo: %{__adapter__: Adapter.Postgres}
          }
        )

        refute_receive {:api_request, _}
      end)
    end

    test "ignores excluded queries" do
      with_config([insights_config: %{ecto: %{excluded_queries: [~r/FROM colors/]}}], fn ->
        :telemetry.execute(
          [:a, :b, :query],
          %{},
          %{
            query: "SELECT a, b FROM colors WHERE a = ?",
            source: "users",
            repo: %{__adapter__: Adapter.Postgres}
          }
        )

        refute_receive {:api_request, _}
      end)
    end
  end

  describe "obfuscate/2" do
    test "replaces single quoted strings and numbers for non-Postgres adapter" do
      sql = "  SELECT * FROM users WHERE name = 'John' AND age = 42  "
      expected = "SELECT * FROM users WHERE name = '?' AND age = ?"
      assert Insights.Ecto.obfuscate(sql, "Ecto.Adapters.MySQL") == expected
    end

    test "replaces double quoted strings for non-Postgres adapter" do
      sql = "SELECT * FROM items WHERE category = \"books\""
      expected = "SELECT * FROM items WHERE category = \"?\""
      assert Insights.Ecto.obfuscate(sql, "Ecto.Adapters.MySQL") == expected
    end

    test "leaves double quoted strings intact for Postgres adapter" do
      sql = "SELECT * FROM items WHERE category = \"books\""
      expected = "SELECT * FROM items WHERE category = \"books\""
      assert Insights.Ecto.obfuscate(sql, "Ecto.Adapters.Postgres") == expected
    end

    test "combines multiple replacements" do
      sql = "INSERT INTO users (name, age, token) VALUES ('Alice', 30, 'secret')"
      expected = "INSERT INTO users (name, age, token) VALUES ('?', ?, '?')"
      assert Insights.Ecto.obfuscate(sql, "Ecto.Adapters.MySQL") == expected
    end
  end
end
