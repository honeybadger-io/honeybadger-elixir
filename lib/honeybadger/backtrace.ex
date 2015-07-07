defmodule Honeybadger.Backtrace do

  def from_stacktrace(stacktrace) do
    Enum.map stacktrace, &format_line/1
  end

  defp format_line({mod, fun, _args, [file: file, line: line]}) do
      file = List.to_string file
      fun = Atom.to_string fun
      %{file: file, method: fun, number: line, app: get_app(mod)}
  end

  defp get_app(module) do
    case :application.get_application(module) do
      {:ok, app} -> app
      :undefined -> nil
    end
  end
end
