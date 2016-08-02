defmodule Honeybadger.Notice do
  alias Honeybadger.Utils

  defstruct [:notifier, :server, :error, :request]

  def new(exception, metadata \\ %{}, backtrace) do
    exception = Exception.normalize(:error, exception)
    exception_mod = exception.__struct__
    error = %{
      class: Utils.strip_elixir_prefix(exception_mod),
      message: exception_mod.message(exception),
      tags: Dict.get(metadata, :tags, []),
      backtrace: backtrace
    }
    context = Dict.get(metadata, :context, %{})
    request = Dict.get(metadata, :plug_env, %{})
              |> Dict.put(:context, context)

    %__MODULE__{error: error,
                request: request,
                notifier: notifier(),
                server: server()}
  end

  url = get_in(Honeybadger.Mixfile.project, [:package, :links, "GitHub"])
  version = Honeybadger.Mixfile.project[:version]

  defp notifier do
    %{name: "Honeybadger Elixir Notifier",
      url: unquote(url),
      version: unquote(version)}
  end

  defp server do
    %{environment_name: environment_name(),
      hostname: hostname(),
      project_root: project_root()}
  end

  defp hostname do
    Application.get_env(:honeybadger, :hostname)
  end

  defp project_root do
    Application.get_env(:honeybadger, :project_root)
  end

  defp environment_name do
    Application.get_env(:honeybadger, :environment_name)
  end
end
