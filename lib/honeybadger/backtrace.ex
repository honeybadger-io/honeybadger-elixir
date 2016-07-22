defmodule Honeybadger.Backtrace do

  def from_stacktrace(stacktrace) do
    Enum.map stacktrace, &format_line/1
  end

  defp format_line({mod, fun, args, []}) do
    format_line({mod, fun, args, [file: [], line: nil]})
  end

  defp format_line({mod, fun, _args, [file: file, line: line]}) do
    %{file: file |> convert_string, method: fun |> convert_string, number:
      line, context: get_context(otp_app(), get_app(mod))}
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
  defp get_context(_app1, _app2),             do: "all"

  defp convert_string(""), do: nil
  defp convert_string(string) when is_binary(string), do: string
  defp convert_string(obj), do: to_string(obj) |> convert_string
end
