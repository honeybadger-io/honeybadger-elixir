defmodule Honeybadger.Mixfile do
  use Mix.Project

  def project do
    [app: :honeybadger,
     version: "0.7.0-beta",
     elixir: "~> 1.2",
     build_embedded: Mix.env() == :prod,
     start_permanent: Mix.env() == :prod,
     deps: deps(),
     package: package(),
     name: "Honeybadger",
     homepage_url: "https://honeybadger.io",
     source_url: "https://github.com/honeybadger-io/honeybadger-elixir",
     description: "Elixir client, Plug and error_logger for integrating with the Honeybadger.io exception tracker",
     docs: [extras: ["README.md", "CHANGELOG.md"],
            main: "readme"]]
  end

  def application do
    [applications: [:hackney, :logger, :poison],
     env: [api_key: {:system, "HONEYBADGER_API_KEY"},
           app: nil,
           environment_name: Mix.env(),
           exclude_envs: [:dev, :test],
           origin: "https://api.honeybadger.io",
           proxy: nil,
           proxy_auth: {nil, nil},
           use_logger: true,
           notice_filter: Honeybadger.NoticeFilter.Default,
           filter: Honeybadger.Filter.Default,
           filter_keys: [:password, :credit_card],
           filter_disable_url: false,
           filter_disable_params: false,
           filter_disable_session: false],
     mod: {Honeybadger, []}]
  end

  defp deps do
    [{:hackney, "~> 1.1"},
     {:poison, "~> 2.0 or ~> 3.0"},
     {:plug, ">= 0.13.0 and < 2.0.0"},

     # Dev dependencies
     {:ex_doc, "~> 0.7", only: :dev},

     # Test dependencies
     {:meck, "~> 0.8.3", only: :test},
     {:cowboy, "~> 1.0.0", only: :test}]
  end

  defp package do
    [licenses: ["MIT"],
     maintainers: ["Joshua Wood"],
     links: %{"GitHub" => "https://github.com/honeybadger-io/honeybadger-elixir"}]
  end
end
