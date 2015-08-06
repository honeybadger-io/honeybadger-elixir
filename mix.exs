defmodule Honeybadger.Mixfile do
  use Mix.Project

  def project do
    [app: :honeybadger,
     version: "0.1.0",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,
     name: "Honeybadger",
     source_url: "https://github.com/honeybadger-io/honeybadger-elixir",
     homepage_url: "https://honeybadger.io",
     description: "Elixir client, Plug and error_logger for integrating with the Honeybadger.io exception tracker"]
  end

  def application do
    [applications: [:httpoison, :logger],
     mod: {Honeybadger, []}]
  end

  defp deps do
    [{:httpoison, "~> 0.7"},
     {:poison, "~> 1.4"},
     {:plug, "~> 0.13"},

     # Test dependencies
     {:meck, "~> 0.8.3", only: :test}]
  end

  defp package do
    [licenses: ["MIT"],
     contributors: ["Richard Bishop, Josh Wood"],
     links: %{"GitHub" => "https://github.com/honeybadger-io/honeybadger-elixir"}]
  end
end
