defmodule Honeybadger.BacktraceTest do
  use Honeybadger.Case, async: true

  alias Honeybadger.Backtrace

  test "converting a stacktrace to the format Honeybadger expects" do
    stacktrace = [
      {:erlang, :some_func, [{:ok, 123}], []},
      {Honeybadger, :notify, [%RuntimeError{message: "error"}, %{a: 1}, [:a, :b]],
       [file: ~c"lib/honeybadger.ex", line: 38]},
      {Honeybadger.Backtrace, :from_stacktrace, 1,
       [file: ~c"lib/honeybadger/backtrace.ex", line: 4, error_info: %{module: :erl_erts_errors}]}
    ]

    with_config([filter_args: false], fn ->
      assert [entry_1, entry_2, entry_3] = Backtrace.from_stacktrace(stacktrace)

      assert entry_1 == %{
               file: nil,
               number: nil,
               method: "some_func/1",
               args: ["{:ok, 123}"],
               context: "all"
             }

      assert entry_2 == %{
               file: "lib/honeybadger.ex",
               number: 38,
               method: "notify/3",
               args: ["%RuntimeError{message: \"error\"}", "%{a: 1}", "[:a, :b]"],
               context: "all"
             }

      assert entry_3 == %{
               file: "lib/honeybadger/backtrace.ex",
               number: 4,
               method: "from_stacktrace/1",
               args: [],
               context: "all"
             }
    end)
  end

  test "including args can be disabled" do
    stacktrace = [{Honeybadger, :something, [1, 2, 3], []}]

    with_config([filter_args: true], fn ->
      assert [entry_1] = Backtrace.from_stacktrace(stacktrace)
      assert match?(%{method: "something/3", args: []}, entry_1)
    end)
  end

  test "args are included by default" do
    stacktrace = [{Honeybadger, :something, [1, 2, 3], []}]

    [
      %{
        args: ["1", "2", "3"],
        context: "all",
        file: nil,
        method: "something/3",
        number: nil
      }
    ] = Backtrace.from_stacktrace(stacktrace)
  end
end
