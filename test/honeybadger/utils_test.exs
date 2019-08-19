defmodule Honeybadger.UtilsTest do
  use ExUnit.Case, async: true

  doctest Honeybadger.Utils
  alias Honeybadger.Utils

  test "sanitize drops nested hash based on depth" do
    item = %{
      a: %{
        b: 12
      },
      c: "string"
    }

    assert Utils.sanitize(item, max_depth: 1) == %{
             a: "[DEPTH]",
             c: "string"
           }
  end

  test "sanitize drops nested lists based on depth" do
    item = [[[a: 12]], 1, 2, 3]

    assert Utils.sanitize(item, max_depth: 2) == [["[DEPTH]"], 1, 2, 3]
  end

  test "sanitize truncates strings" do
    item = "123456789"

    assert Utils.sanitize(item, max_string_size: 3) == "123[TRUNCATED]"
  end

  test "sanitize removes filtered_keys" do
    item = %{
      filter_me: "secret stuff",
      okay: "not a secret at all"
    }

    assert Utils.sanitize(item, filter_keys: [:filter_me]) == %{
             filter_me: "[FILTERED]",
             okay: "not a secret at all"
           }
  end
end
