defmodule Honeybadger.Backtrace do

  def from_stacktrace(stacktrace) do
    Enum.map stacktrace, &format_line/1
  end

  defp format_line({mod, fun, _args, [file: file, line: line]}) do
      file = List.to_string file
      fun = Atom.to_string fun
      %{file: file, method: fun, number: line, context: get_context(otp_app, get_app(mod))}
  end

  defp get_app(module) do
    case :application.get_application(module) do
      {:ok, app} -> app
      :undefined -> nil
    end
  end

  defp otp_app do
    Application.get_env(:honeybadger, :app)
  end

  defp get_context(app, app) when app != nil, do: "app"
  defp get_context(_app, app),                do: "all"
end
