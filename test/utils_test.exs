defmodule Honeybadger.UtilsTest do
  use ExUnit.Case
  import Honeybadger.Utils

  test "strip_elixir_prefix removes Elixir from a module name" do
    stripped = strip_elixir_prefix(Honeybadger.Notice)

    assert "Honeybadger.Notice" == stripped
    refute String.starts_with?(stripped, "Elixir.")
  end
end
