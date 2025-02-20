defmodule Mixapp.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mixapp,
      version: "0.1.0",
      elixir: "~> 1.3",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Mixapp.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:honeybadger, path: "../../"},
      {:req, "~> 0.5.0", only: [:test]}
    ]
  end
end
