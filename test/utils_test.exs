defmodule Honeybadger.UtilsTest do
  use ExUnit.Case
  import Honeybadger.Utils

  test "strip_elixir_prefix removes Elixir from a module name" do
    stripped = strip_elixir_prefix(Honeybadger.Notice)

    assert "Honeybadger.Notice" == stripped
    refute String.starts_with?(stripped, "Elixir.")
  end

  test "exception_from_message" do
    runtime_error_message = "** (RuntimeError) Oops"
    file_error_message = """
        ** (File.Error) could not read file doesnt_exist.txt: no such file or directory
    """

    assert %RuntimeError{message: "Oops"} == 
           exception_from_message(runtime_error_message)
    assert %File.Error{reason: "could not read file doesnt_exist.txt: no such file or directory"} ==
           exception_from_message(file_error_message)
  end

  test "atomize_keys" do
    atoms = [exception: RuntimeError, message: "Oops"]
    strings = %{"exception" => RuntimeError, "message" => "Oops"}
    mixed = %{exception: RuntimeError} |> Map.put("message", "Oops")

    assert atoms == atomize_keys(atoms)
    assert atoms == atomize_keys(strings)
    assert atoms == atomize_keys(mixed)
  end
end
