defmodule Honeybadger.IntegrationTest do
  use Honeybadger.Case
  @tag timeout: 2 * 60_000
  test "mix app integration tests" do
    IO.puts("\n====================\nmix app integration tests")

    assert exec(["mix", ["deps.get"], [cd: "./dummy/mixapp"]]) == 0
    assert exec(["mix", ["test"], [cd: "./dummy/mixapp"]]) == 0

    IO.puts("====================")
  end

  defp exec(args) do
    {out, exit_code} = apply(System, :cmd, args)
    IO.puts(out)
    exit_code
  end
end
