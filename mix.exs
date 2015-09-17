defmodule Honeybadger.Mixfile do
  use Mix.Project
  @mix_env Mix.env
  def project do
    [app: :honeybadger,
     version: "0.1.2",
     elixir: "~> 1.0",
     build_embedded: @mix_env == :prod,
     start_permanent: @mix_env == :prod,
     deps: deps,
     package: package,
     name: "Honeybadger",
     homepage_url: "https://honeybadger.io",
     description: "Elixir client, Plug and error_logger for integrating with the Honeybadger.io exception tracker",
     docs: [readme: "README.md", main: "README",
            source_url: "https://github.com/honeybadger-io/honeybadger-elixir"]]
  end

  def application do
    [applications: [:httpoison, :logger],
     mod: {Honeybadger, []}]
  end

  defp deps do
    [{:httpoison, "~> 0.7"},
     {:poison, "~> 1.4"},
     {:plug, "~> 0.13 or ~> 1.0"},

     # Dev dependencies
     {:ex_doc, "~> 0.7", only: :dev},

     # Test dependencies
     {:meck, "~> 0.8.3", only: :test}]
  end

  defp package do
    [licenses: ["MIT"],
     contributors: ["Richard Bishop, Josh Wood"],
     links: %{"GitHub" => "https://github.com/honeybadger-io/honeybadger-elixir"}]
  end
end
