defmodule Honeybadger.Insights.EctoTest do
  use ExUnit.Case, async: true

  alias Honeybadger.Insights.Ecto

  describe "obfuscate/2" do
    test "replaces single quoted strings and numbers for non-Postgres adapter" do
      sql = "  SELECT * FROM users WHERE name = 'John' AND age = 42  "
      expected = "SELECT * FROM users WHERE name = '?' AND age = ?"
      assert Ecto.obfuscate(sql, "Ecto.Adapters.MySQL") == expected
    end

    test "replaces double quoted strings for non-Postgres adapter" do
      sql = "SELECT * FROM items WHERE category = \"books\""
      expected = "SELECT * FROM items WHERE category = \"?\""
      assert Ecto.obfuscate(sql, "Ecto.Adapters.MySQL") == expected
    end

    test "leaves double quoted strings intact for Postgres adapter" do
      sql = "SELECT * FROM items WHERE category = \"books\""
      expected = "SELECT * FROM items WHERE category = \"books\""
      assert Ecto.obfuscate(sql, "Ecto.Adapters.Postgres") == expected
    end

    test "combines multiple replacements" do
      sql = "INSERT INTO users (name, age, token) VALUES ('Alice', 30, 'secret')"
      expected = "INSERT INTO users (name, age, token) VALUES ('?', ?, '?')"
      assert Ecto.obfuscate(sql, "Ecto.Adapters.MySQL") == expected
    end
  end
end
