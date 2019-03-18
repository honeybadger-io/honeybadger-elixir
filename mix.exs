defmodule Honeybadger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :honeybadger,
      version: "0.11.0",
      elixir: "~> 1.7",
      consolidate_protocols: Mix.env() != :test,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      package: package(),
      name: "Honeybadger",
      homepage_url: "https://honeybadger.io",
      source_url: "https://github.com/honeybadger-io/honeybadger-elixir",
      description:
        "Elixir client, Plug and error_logger for integrating with the Honeybadger.io exception tracker",

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:plug, :mix],
        flags: [:error_handling, :race_conditions, :underspecs]
      ],

      # Docs
      docs: [extras: ["README.md", "CHANGELOG.md"], main: "readme"]
    ]
  end

  # we use a non standard location for mix tasks as we don't want them to leak
  # into the host apps mix tasks. This way our release task is shown only in our mix tasks
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      applications: [:hackney, :logger, :jason],
      env: [
        api_key: {:system, "HONEYBADGER_API_KEY"},
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
        filter_args: true,
        filter_disable_url: false,
        filter_disable_params: false,
        filter_disable_session: false
      ],
      mod: {Honeybadger, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.1"},
      {:jason, "~> 1.0"},
      {:plug, ">= 1.0.0 and < 2.0.0", optional: true},
      {:phoenix, ">= 1.0.0 and < 2.0.0", optional: true},

      # Dev dependencies
      {:ex_doc, "~> 0.7", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},

      # Test dependencies
      {:plug_cowboy, ">= 1.0.0 and < 3.0.0", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Joshua Wood"],
      links: %{"GitHub" => "https://github.com/honeybadger-io/honeybadger-elixir"}
    ]
  end
end
