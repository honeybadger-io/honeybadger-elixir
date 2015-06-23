defmodule Honeybadger.Notice do
  @hostname Application.get_env(:honeybadger, :hostname)
  @project_root Application.get_env(:honeybadger, :project_root)

  @notifier_info %{
    name: "Honeybadger Elixir Notifier",
    url: get_in(Honeybadger.Mixfile.project, [:package, :links, "GitHub"]),
    version: Honeybadger.Mixfile.project[:version]
  }

  @server_info %{
    environment_name: Mix.env,
    hostname: @hostname,
    project_root: %{
      path: @project_root
    }
  }

  defstruct notifier: @notifier_info, server: @server_info, error: %{}, request: %{}

  def new(exception, backtrace, metadata \\ %{}) do
    error = %{
      class: exception.__struct__,
      message: exception.message,
      tags: Dict.get(metadata, :tags, []),
      backtrace: backtrace
    }
    request = %{
      context: Dict.get(metadata, :context, %{})
    }

    %__MODULE__{error: error, request: request}
  end
end
