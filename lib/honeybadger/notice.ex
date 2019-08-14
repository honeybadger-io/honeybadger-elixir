defmodule Honeybadger.Notice do
  @doc false

  alias Honeybadger.{Backtrace, Utils}
  alias Honeybadger.Breadcrumbs.{Collector}

  @type error :: %{class: atom | iodata, message: iodata, tags: list, backtrace: list}
  @type notifier :: %{name: String.t(), url: String.t(), version: String.t()}

  @type server :: %{
          environment_name: atom,
          hostname: String.t(),
          project_root: Path.t(),
          revision: String.t()
        }

  @type noticeable :: Exception.t() | String.t() | map() | atom()

  @type t :: %__MODULE__{
          notifier: notifier(),
          server: server(),
          error: error(),
          breadcrumbs: Collector.t(),
          request: map()
        }

  @url get_in(Honeybadger.Mixfile.project(), [:package, :links, "GitHub"])
  @version Honeybadger.Mixfile.project()[:version]
  @notifier %{name: "Honeybadger Elixir Notifier", url: @url, version: @version}

  @derive Jason.Encoder
  @enforce_keys [:breadcrumbs, :notifier, :server, :error, :request]
  defstruct [:breadcrumbs, :notifier, :server, :error, :request]

  @spec new(noticeable(), map(), list()) :: t()
  def new(error, metadata, stacktrace)

  def new(message, metadata, stacktrace)
      when is_binary(message) and is_map(metadata) and is_list(stacktrace) do
    new(%RuntimeError{message: message}, metadata, stacktrace)
  end

  def new(exception, metadata, stacktrace) when is_map(metadata) and is_list(stacktrace) do
    {exception, stacktrace} = Exception.blame(:error, exception, stacktrace)

    %{__struct__: exception_mod} = exception

    error = %{
      class: Utils.module_to_string(exception_mod),
      message: exception_mod.message(exception),
      backtrace: Backtrace.from_stacktrace(stacktrace),
      tags: Map.get(metadata, :tags, [])
    }

    Honeybadger.add_breadcrumb(error[:class],
      metadata: %{exception_message: error[:message]},
      category: "error"
    )

    request =
      metadata
      |> Map.get(:plug_env, %{})
      |> Map.put(:context, Map.get(metadata, :context, %{}))

    filter(%__MODULE__{
      breadcrumbs: Collector.output(),
      error: error,
      request: request,
      notifier: @notifier,
      server: server()
    })
  end

  defp filter(notice) do
    case Honeybadger.get_env(:notice_filter) do
      nil -> notice
      notice_filter -> notice_filter.filter(notice)
    end
  end

  defp server do
    %{
      environment_name: Honeybadger.get_env(:environment_name),
      hostname: Honeybadger.get_env(:hostname),
      project_root: Honeybadger.get_env(:project_root),
      revision: Honeybadger.get_env(:revision)
    }
  end
end
