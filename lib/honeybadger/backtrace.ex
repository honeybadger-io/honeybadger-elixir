defmodule Honeybadger.Backtrace do

  def from_stacktrace(stacktrace) do
    Enum.map stacktrace, &format_line/1
  end

  defp format_line({_mod, fun, _args, [file: file, line: line]}) do
      file = List.to_string file
      fun = Atom.to_string(fun)
      %{number: line, file: file, method: fun}
  end
end
