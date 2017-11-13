defmodule Honeybadger.Backtrace do
  @moduledoc """
  The Backtrace module contains functions for formatting system stacktraces.
  """

  @app_context "app"
  @all_context "all"

  @doc """
  Convert a system stacktrace into an API compatible backtrace.

  The function expects a list of `:erlang.stack_item()` tuples.
  """
  def from_stacktrace(stacktrace) when is_list(stacktrace) do
    Enum.map(stacktrace, &format_line/1)
  end

  defp format_line({mod, fun, args, []}) do
    format_line({mod, fun, args, [file: [], line: nil]})
  end

  defp format_line({mod, fun, args, [file: file, line: line]}) do
    app = Honeybadger.get_env(:app)
    filter_args = Honeybadger.get_env(:filter_args)

    %{file: format_file(file),
      method: format_method(fun, args),
      args: format_args(args, filter_args),
      number: line,
      context: app_context(app, Application.get_application(mod))}
  end

  defp app_context(app, app) when not is_nil(app), do: @app_context
  defp app_context(_app1, _app2), do: @all_context

  defp format_file(""), do: nil
  defp format_file(file) when is_binary(file), do: file
  defp format_file(file), do: file |> to_string() |> format_file()

  defp format_method(fun, args) when is_list(args) do
    format_method(fun, length(args))
  end
  defp format_method(fun, arity) when is_integer(arity) do
    "#{fun}/#{arity}"
  end

  defp format_args(args, false = _filter) when is_list(args) do
    Enum.map(args, &inspect/1)
  end
  defp format_args(_arity, _filter) do
    []
  end
end
