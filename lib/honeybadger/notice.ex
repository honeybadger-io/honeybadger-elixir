defmodule Honeybadger.Notice do
  @moduledoc """
  A `Honeybadger.Notice` struct is used to bundle an exception with system
  information.
  """

  alias __MODULE__
  alias Honeybadger.Utils

  @typep error :: %{class: atom | iodata, message: iodata, tags: list, backtrace: list}

  @type noticeable :: Exception.t() | Map.t() | String.t() | atom

  @typep notifier :: %{name: String.t(), url: String.t(), version: String.t()}

  @typep server :: %{environment_name: atom, hostname: String.t(), project_root: Path.t()}

  @type t :: %__MODULE__{
          notifier: notifier,
          server: server,
          error: error,
          request: Map.t()
        }

  @enforce_keys [:notifier, :server, :error, :request]

  defstruct [:notifier, :server, :error, :request]

  @doc """
  Create a new `Honeybadger.Notice` struct for various error types.

  ## Example

      iex> Honeybadger.Notice.new("oops", %{}, []).error
      %{backtrace: [], class: "RuntimeError", message: "oops", tags: []}

      iex> Honeybadger.Notice.new(:badarg, %{}, []).error
      %{backtrace: [], class: "ArgumentError", message: "argument error", tags: []}

      iex> Honeybadger.Notice.new(%RuntimeError{message: "oops"}, %{}, []).error
      %{backtrace: [], class: "RuntimeError", message: "oops", tags: []}
  """
  @spec new(noticeable, Map.t(), list) :: t
  def new(error, metadata, backtrace)

  def new(message, metadata, backtrace) when is_binary(message) do
    new(%RuntimeError{message: message}, metadata, backtrace)
  end

  def new(%{class: class, message: message}, metadata, backtrace) do
    %{class: class, message: message, backtrace: backtrace}
    |> create(metadata)
  end

  def new(exception, metadata, backtrace) do
    exception = Exception.normalize(:error, exception)

    %{__struct__: exception_mod} = exception

    error = %{
      class: Utils.module_to_string(exception_mod),
      message: exception_mod.message(exception),
      backtrace: backtrace
    }

    create(error, metadata)
  end

  defp create(error, metadata) do
    error = Map.put(error, :tags, Map.get(metadata, :tags, []))
    context = Map.get(metadata, :context, %{})

    request =
      metadata
      |> Map.get(:plug_env, %{})
      |> Map.put(:context, context)

    %Notice{error: error, request: request, notifier: notifier(), server: server()}
    |> filter(Honeybadger.get_env(:notice_filter))
  end

  url = get_in(Honeybadger.Mixfile.project(), [:package, :links, "GitHub"])
  version = Honeybadger.Mixfile.project()[:version]

  defp filter(notice, nil), do: notice
  defp filter(notice, app_filter), do: app_filter.filter(notice)

  defp notifier do
    %{name: "Honeybadger Elixir Notifier", url: unquote(url), version: unquote(version)}
  end

  defp server do
    %{
      environment_name: Honeybadger.get_env(:environment_name),
      hostname: Honeybadger.get_env(:hostname),
      project_root: Honeybadger.get_env(:project_root)
    }
  end
end
