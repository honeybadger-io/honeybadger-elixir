defmodule Honeybadger.UtilsTest do
  use ExUnit.Case, async: true

  doctest Honeybadger.Utils
  alias Honeybadger.Utils

  test "sanitize drops nested hash based on depth" do
    item = %{
      a: %{
        b: 12,
        m: %{
          j: 3
        }
      },
      c: "string"
    }

    assert Utils.sanitize(item, max_depth: 2) == %{
             a: %{
               b: 12,
               m: "[DEPTH]"
             },
             c: "string"
           }
  end

  test "sanitize drops nested lists based on depth" do
    item = [[[a: 12]], 1, 2, 3]

    assert Utils.sanitize(item, max_depth: 2) == [["[DEPTH]"], 1, 2, 3]
  end

  test "converts dates to ISO8601" do
    item = %{
      date: ~D[2023-10-01],
      datetime: ~U[2023-10-01 12:00:00Z],
      naive_datetime: ~N[2023-10-01 12:00:00]
    }

    assert Utils.sanitize(item) == %{
             date: "2023-10-01",
             datetime: "2023-10-01T12:00:00Z",
             naive_datetime: "2023-10-01T12:00:00"
           }
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

  test "sanitize removes nested keys" do
    item = %{
      key1: "val1",
      key2: %{
        __remove__: "val2"
      }
    }

    assert Utils.sanitize(item, filter_keys: [:__remove__], remove_filtered: true) == %{
             key1: "val1"
           }
  end
end
