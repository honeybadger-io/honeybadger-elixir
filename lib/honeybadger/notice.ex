defmodule Honeybadger.Notice do
  alias Honeybadger.Utils

  defstruct [:notifier, :server, :error, :request]


  def new(error, metadata \\ %{}, backtrace)

  def new(%{class: class, message: message}, metadata, backtrace) do
    error = %{
      class: class,
      message: message,
      tags: Map.get(metadata, :tags, []),
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
      tags: Map.get(metadata, :tags, []),
      backtrace: backtrace
    }
    create(error, metadata)
  end

  defp create(error, metadata) do
    context = Map.get(metadata, :context, %{})
    request = Map.get(metadata, :plug_env, %{})
              |> Map.put(:context, context)

    %__MODULE__{error: error,
                request: request,
                notifier: notifier(),
                server: server()}
     |> filter(Honeybadger.get_env(:notice_filter))
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
    %{environment_name: Honeybadger.get_env(:environment_name),
      hostname: Honeybadger.get_env(:hostname),
      project_root: Honeybadger.get_env(:project_root)}
  end
end
