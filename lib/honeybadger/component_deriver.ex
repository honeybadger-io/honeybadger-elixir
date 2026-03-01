defmodule Honeybadger.ComponentDeriver do
  @moduledoc """
  Derives a component name from a stacktrace for better error grouping.

  When errors occur outside of web requests (e.g., in background jobs, GenServers,
  or Tasks), there's no Phoenix controller to use as the component. This module
  analyzes the stacktrace to find a meaningful "origin" module that can serve as
  the component for fingerprinting purposes.

  The Honeybadger API uses the component field (along with exception class and
  the first application backtrace frame) to group errors. Without a component,
  errors with similar stacktraces may be incorrectly grouped together.

  ## How It Works

  The deriver walks through the stacktrace looking for the first frame that:
  1. Belongs to the configured application (`:app` config)
  2. Is not in the list of skipped "infrastructure" modules

  Infrastructure modules are things like `Ecto.Repo`, `Ecto.Changeset`, etc. that
  appear in many stacktraces but don't indicate where the error actually originated.

  ## Configuration

  You can customize which modules are skipped:

      config :honeybadger,
        component_deriver_skip_patterns: [
          Ecto.Repo,
          Ecto.Changeset,
          MyApp.CustomInfraModule,
          ~r/^MyApp\\.Internal/
        ]

  Patterns can be module atoms, strings, or regexes. The default skip list
  includes common Ecto and database-related modules.
  """

  alias Honeybadger.Utils

  @doc """
  Derives a component name from a stacktrace.

  Returns the module name as a string if a suitable component is found,
  or `nil` if no suitable module could be determined.

  ## Parameters

    * `stacktrace` - An Elixir stacktrace (list of stack frames)
    * `opts` - Optional keyword list with:
      * `:app` - The application atom to match against (defaults to Honeybadger config)
      * `:skip_patterns` - List of regex patterns for modules to skip

  ## Examples

      iex> stacktrace = [
      ...>   {MyApp.Users, :create, 2, [file: 'lib/my_app/users.ex', line: 42]},
      ...>   {Ecto.Repo, :insert, 2, [file: 'lib/ecto/repo.ex', line: 100]}
      ...> ]
      iex> Honeybadger.ComponentDeriver.derive(stacktrace)
      "MyApp.Users"

  """
  @spec derive(Exception.stacktrace(), keyword()) :: String.t() | nil
  def derive(stacktrace, opts \\ [])

  def derive([], _opts), do: nil

  def derive(stacktrace, opts) when is_list(stacktrace) do
    app = Keyword.get_lazy(opts, :app, fn -> Honeybadger.get_env(:app) end)
    skip_patterns = Keyword.get(opts, :skip_patterns, skip_patterns())

    stacktrace
    |> Enum.find(&suitable_frame?(&1, app, skip_patterns))
    |> frame_to_component()
  end

  @doc """
  Returns the list of module patterns to skip when deriving components.

  This combines the default patterns with any user-configured patterns.
  """
  @spec skip_patterns() :: [Regex.t()]
  def skip_patterns do
    user_patterns =
      Application.get_env(:honeybadger, :component_deriver_skip_patterns, [])
      |> Enum.map(&pattern_to_regex/1)

    default_skip_patterns() ++ user_patterns
  end

  defp default_skip_patterns do
    [
      # Ecto infrastructure - these appear in most DB error stacktraces
      ~r/^Ecto\.Repo/,
      ~r/^Ecto\.Changeset/,
      ~r/^Ecto\.Adapters/,
      ~r/^Ecto\.Multi/,
      ~r/^Ecto\.Query/,
      # Database drivers
      ~r/^Postgrex/,
      ~r/^Mariaex/,
      ~r/^MyXQL/,
      ~r/^Exqlite/,
      ~r/^DBConnection/,
      # Telemetry
      ~r/^Telemetry/,
      ~r/^:telemetry/
    ]
  end

  # Convert user-provided patterns to regex
  defp pattern_to_regex(%Regex{} = regex), do: regex
  defp pattern_to_regex(module) when is_atom(module), do: module_to_regex(module)

  defp pattern_to_regex(string) when is_binary(string),
    do: Regex.compile!("^#{Regex.escape(string)}")

  defp module_to_regex(module) do
    module
    |> Utils.module_to_string()
    |> Regex.escape()
    |> then(&Regex.compile!("^#{&1}"))
  end

  # Check if a stack frame is suitable for use as a component
  defp suitable_frame?({module, _fun, _arity_or_args, _location}, app, skip_patterns) do
    app_matches?(module, app) && !skipped?(module, skip_patterns)
  end

  defp suitable_frame?(_frame, _app, _skip_patterns), do: false

  # Check if the module belongs to the configured application
  defp app_matches?(_module, nil), do: false

  defp app_matches?(module, app) do
    Application.get_application(module) == app
  end

  # Check if the module matches any skip patterns
  defp skipped?(module, skip_patterns) do
    module_string = Utils.module_to_string(module)
    Enum.any?(skip_patterns, &Regex.match?(&1, module_string))
  end

  # Extract the component name from a stack frame
  defp frame_to_component(nil), do: nil

  defp frame_to_component({module, _fun, _arity_or_args, _location}) do
    Utils.module_to_string(module)
  end
end
