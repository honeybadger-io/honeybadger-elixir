defmodule Honeybadger.Notice do
  alias Honeybadger.Utils

  defstruct [:notifier, :server, :error, :request]

  @known_fields [:plug_env, :tags]

  def new(exception, metadata \\ %{}, backtrace) do
    error = %{
      class: Utils.strip_elixir_prefix(exception.__struct__),
      message: exception.message,
      tags: Dict.get(metadata, :tags, []),
      backtrace: format_backtrace(backtrace)
    }

    context = Dict.drop(metadata, @known_fields)
    request = metadata
              |> Dict.get(:plug_env, %{})
              |> Dict.merge(%{context: context})

    %__MODULE__{error: error, request: request, notifier: notifier, server: server}
  end

  defp notifier do
    %{
      name: "Honeybadger Elixir Notifier",
      url: get_in(Honeybadger.Mixfile.project, [:package, :links, "GitHub"]),
      version: Honeybadger.Mixfile.project[:version]
    }
  end

  defp server do
    %{
      environment_name: Mix.env,
      hostname: hostname,
      project_root: project_root
    }
  end

  defp hostname do
    Application.get_env(:honeybadger, :hostname)
  end

  defp project_root do
    Application.get_env(:honeybadger, :project_root)
  end

  defp otp_app do
    Application.get_env(:honeybadger, :app)
  end

  defp format_backtrace(backtrace) do
    Enum.map(backtrace, &format_line/1)
  end

  defp format_line(%{file: file, method: fun, number: line, app: app}) do
    %{file: file, method: fun, number: line, context: get_context(otp_app, app)}
  end

  defp get_context(app, app) when app != nil, do: "app"
  defp get_context(_app, app),                do: "all"
end
