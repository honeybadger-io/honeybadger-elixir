defmodule Honeybadger.Notice do
  @doc false

  alias Honeybadger.{Backtrace, ComponentDeriver, Utils}
  alias Honeybadger.Breadcrumbs.{Collector}

  @type error :: %{
          backtrace: list,
          class: atom | iodata,
          fingerprint: String.t(),
          message: iodata,
          tags: list
        }

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
          request: map(),
          correlation_context: map()
        }

  @url get_in(Honeybadger.Mixfile.project(), [:package, :links, "GitHub"])
  @version Honeybadger.Mixfile.project()[:version]
  @notifier %{name: "honeybadger-elixir", language: "elixir", url: @url, version: @version}

  @derive Jason.Encoder
  @enforce_keys [:breadcrumbs, :notifier, :server, :error, :request, :correlation_context]
  defstruct [:breadcrumbs, :notifier, :server, :error, :request, :correlation_context]

  @spec new(noticeable(), map(), list(), String.t()) :: t()
  def new(error, metadata, stacktrace, fingerprint \\ "")

  def new(message, metadata, stacktrace, fingerprint)
      when is_binary(message) and is_map(metadata) and is_list(stacktrace) do
    new(%RuntimeError{message: message}, metadata, stacktrace, fingerprint)
  end

  def new(%{class: exception_name, message: message}, metadata, stacktrace, fingerprint)
      when is_map(metadata) and is_list(stacktrace) do
    new(exception_name, message, metadata, stacktrace, fingerprint)
  end

  def new(exception, metadata, stacktrace, fingerprint)
      when is_map(metadata) and is_list(stacktrace) do
    {exception, _stacktrace} = Exception.blame(:error, exception, stacktrace)

    %{__struct__: exception_mod} = exception

    class = Utils.module_to_string(exception_mod)
    message = exception_mod.message(exception)

    new(class, message, metadata, stacktrace, fingerprint)
  end

  # bundles exception (or pseudo exception) information in to notice
  defp new(class, message, metadata, stacktrace, fingerprint) do
    message = if message, do: IO.iodata_to_binary(message), else: nil

    error = %{
      class: class,
      message: message,
      backtrace: Backtrace.from_stacktrace(stacktrace),
      tags: Map.get(metadata, :tags, []),
      fingerprint: fingerprint
    }

    plug_env = Map.get(metadata, :plug_env, %{})
    context = Map.get(metadata, :context, %{})

    # Derive a component from the stacktrace if one isn't already set.
    # This helps with error grouping for non-web errors (background jobs, etc.)
    context = maybe_derive_component(context, plug_env, stacktrace)

    request =
      plug_env
      |> Map.put(:context, context)

    correlation_context = Map.take(metadata, [:request_id])

    filter(%__MODULE__{
      breadcrumbs: Map.get(metadata, :breadcrumbs, %{}),
      error: error,
      request: request,
      notifier: @notifier,
      server: server(),
      correlation_context: correlation_context
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

  # Derives a component from the stacktrace when one isn't already present.
  # The component is used by Honeybadger's fingerprinting algorithm for grouping.
  defp maybe_derive_component(context, plug_env, stacktrace) do
    cond do
      # User already set _component in context - don't override
      Map.has_key?(context, :_component) or Map.has_key?(context, "_component") ->
        context

      # There's a component from plug_env (web request) - don't need to derive
      plug_env[:component] not in [nil, ""] ->
        context

      # No component - derive one from the stacktrace
      true ->
        case ComponentDeriver.derive(stacktrace) do
          nil -> context
          component -> Map.put(context, :_component, component)
        end
    end
  end
end
