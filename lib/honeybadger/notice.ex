defmodule Honeybadger.Notice do
  alias Honeybadger.Utils

  defstruct [:notifier, :server, :error, :request]

  @known_fields [:plug_env, :tags]

  def new(exception, metadata \\ %{}, backtrace) do
    error = %{
      class: Utils.strip_elixir_prefix(exception.__struct__),
      message: exception.message,
      tags: Dict.get(metadata, :tags, []),
      backtrace: backtrace
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
end
