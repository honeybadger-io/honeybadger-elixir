defmodule Honeybadger.UtilsTest do
  use ExUnit.Case
  alias Honeybadger.Utils

  test "strip_elixir_prefix removes Elixir from a module name" do
    refute Elixir.Honeybadger.Notice == Utils.strip_elixir_prefix Honeybadger.Notice
  end
end
