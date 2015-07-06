defmodule Honeybadger.Mixfile do
  use Mix.Project

  def project do
    [app: :honeybadger,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,
     name: "Honeybadger",
     source_url: "https://github.com/honeybadger-io/honeybadger-elixir",
     homepage_url: "https://honeybadger.io",
     description: "Elixir client, plug and logger for integrating with Honeybadger exception tracker"]
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
     {:cowboy, "~> 1.0.0", only: :test},
     {:mock, "~> 0.1.1", only: :test}]
  end

  defp package do
    %{
      licenses: ["MIT"],
      contributors: ["Richard Bishop"],
      links: %{
        "GitHub" => "https://github.com/honeybadger-io/honeybadger-elixir"}
    }
  end
end
