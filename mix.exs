defmodule Honeybadger.Mixfile do
  use Mix.Project

  def project do
    [app: :honeybadger,
     version: "0.5.0",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,
     name: "Honeybadger",
     homepage_url: "https://honeybadger.io",
     source_url: "https://github.com/honeybadger-io/honeybadger-elixir",
     description: "Elixir client, Plug and error_logger for integrating with the Honeybadger.io exception tracker",
     docs: [extras: ["README.md", "CHANGELOG.md"],
            main: "readme"]]
  end

  def application do
    [applications: [:httpoison, :logger, :poison],
     env: [],
     mod: {Honeybadger, []}]
  end

  defp deps do
    [{:httpoison, "~> 0.9"},
     {:poison, ">= 1.4.0 and < 3.0.0"},
     {:plug, ">= 0.13.0 and < 2.0.0"},

     # Dev dependencies
     {:ex_doc, "~> 0.7", only: :dev},

     # Test dependencies
     {:meck, "~> 0.8.3", only: :test}]
  end

  defp package do
    [licenses: ["MIT"],
     maintainers: ["Richard Bishop, Josh Wood"],
     links: %{"GitHub" => "https://github.com/honeybadger-io/honeybadger-elixir"}]
  end
end
