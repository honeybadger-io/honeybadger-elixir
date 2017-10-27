defmodule Mix.Tasks.Release do
  use Mix.Task

  @shortdoc "Publish package to hex.pm, create a git tag and push it to GitHub"

  @moduledoc """
  release uses shipit.
  It performs many sanity checks before pushing the hex package.
  Check out https://github.com/wojtekmach/shipit for more details
  """

  def run([]) do
    ensure_shipit_installed!()
    Mix.Task.run("shipit", ["master", current_version()])
  end

  def run(_) do
    Mix.raise("""
    Invalid args.

    Usage:

      mix release
    """)
  end

  defp ensure_shipit_installed! do
    loadpaths!()
    Mix.Task.load_all()
    if !Mix.Task.get("shipit") do
      Mix.raise("""
      You don't seem to have the shipit mix task installed on your computer.
      Install it using:

        mix archive.install hex shipit

        Fore more info go to: https://github.com/wojtekmach/shipit
      """)
    end
  end

  defp current_version do
    Mix.Project.config[:version]
  end

  # Copied from Mix.Tasks.Help
  # Loadpaths without checks because tasks may be defined in deps.
  defp loadpaths! do
    Mix.Task.run "loadpaths", ["--no-elixir-version-check", "--no-deps-check", "--no-archives-check"]
    Mix.Task.reenable "loadpaths"
    Mix.Task.reenable "deps.loadpaths"
  end

end
