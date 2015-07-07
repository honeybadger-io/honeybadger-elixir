defmodule Honeybadger.Notice do
  alias Honeybadger.Utils

  defstruct notifier: %{}, server: %{}, error: %{}, request: %{}

  def new(exception, backtrace, metadata \\ %{}) do
    error = %{
      class: Utils.strip_elixir_prefix(exception.__struct__),
      message: exception.message,
      tags: Dict.get(metadata, :tags, []),
      backtrace: backtrace
    }

    request = %{
      context: Dict.get(metadata, :context, %{}),
      url: Dict.get(metadata, :url, ""),
      component: Dict.get(metadata, :component, ""),
      action: Dict.get(metadata, :action, ""),
      params: Dict.get(metadata, :params, %{}),
      session: Dict.get(metadata, :session, %{}),
      cgi_data: Dict.get(metadata, :cgi_data, %{})
    }

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
end
