defmodule Honeybadger.Notice do
  alias Honeybadger.Utils

  defstruct [:notifier, :server, :error, :request]


  def new(error, metadata \\ %{}, backtrace)

  def new(%{class: class, message: message}, metadata, backtrace) do
    error = %{
      class: class,
      message: message,
      tags: Dict.get(metadata, :tags, []),
      backtrace: backtrace
    }
    create(error, metadata)
  end

  def new(exception, metadata, backtrace) do
    exception = Exception.normalize(:error, exception)
    exception_mod = exception.__struct__
    error = %{
      class: Utils.strip_elixir_prefix(exception_mod),
      message: exception_mod.message(exception),
      tags: Dict.get(metadata, :tags, []),
      backtrace: backtrace
    }
    create(error, metadata)
  end

  defp create(error, metadata) do
    context = Dict.get(metadata, :context, %{})
    request = Dict.get(metadata, :plug_env, %{})
              |> Dict.put(:context, context)

    %__MODULE__{error: error,
                request: request,
                notifier: notifier(),
                server: server()}
     |> filter(Application.get_env(:honeybadger, :notice_filter))
  end

  url = get_in(Honeybadger.Mixfile.project, [:package, :links, "GitHub"])
  version = Honeybadger.Mixfile.project[:version]

  defp filter(notice, nil), do: notice
  defp filter(notice, app_filter), do: app_filter.filter(notice)

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
