defmodule Honeybadger.Mixfile do
  use Mix.Project

  @source_url "https://github.com/honeybadger-io/honeybadger-elixir"
  @version "0.20.0"

  def project do
    [
      app: :honeybadger,
      version: @version,
      elixir: "~> 1.11",
      consolidate_protocols: Mix.env() != :test,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      package: package(),
      name: "Honeybadger",
      homepage_url: "https://honeybadger.io",
      description: """
      Elixir client, Plug and error_logger for integrating with the
      Honeybadger.io exception tracker"
      """,

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:plug, :mix, :ecto],
        flags: [:error_handling, :race_conditions, :underspecs]
      ],

      # Xref
      xref: [exclude: [Plug.Conn]],

      # Docs
      docs: [
        main: "readme",
        source_ref: "v#{@version}",
        source_url: @source_url,
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  # We use a non standard location for mix tasks as we don't want them to leak
  # into the host apps mix tasks. This way our release task is shown only in
  # our mix tasks
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      applications: [:hackney, :logger, :jason, :telemetry],
      env: [
        api_key: {:system, "HONEYBADGER_API_KEY"},
        app: nil,
        breadcrumbs_enabled: true,
        ecto_repos: [],
        environment_name: Mix.env(),
        exclude_envs: [:dev, :test],
        sasl_logging_only: true,
        origin: "https://api.honeybadger.io",
        proxy: nil,
        proxy_auth: {nil, nil},
        hackney_opts: [],
        use_logger: true,
        ignored_domains: [:cowboy],
        notice_filter: Honeybadger.NoticeFilter.Default,
        filter: Honeybadger.Filter.Default,
        filter_keys: [:password, :credit_card],
        filter_args: false,
        filter_disable_url: false,
        filter_disable_params: false,
        filter_disable_session: false,
        exclude_errors: []
      ],
      mod: {Honeybadger, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.1"},
      {:jason, "~> 1.0"},
      {:plug, ">= 1.0.0 and < 2.0.0", optional: true},
      {:ecto, ">= 2.0.0", optional: true},
      {:phoenix, ">= 1.0.0 and < 2.0.0", optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0"},

      # Dev dependencies
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:expublish, "~> 2.5", only: [:dev], runtime: false},

      # Test dependencies
      {:plug_cowboy, ">= 2.0.0 and < 3.0.0", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Joshua Wood"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end
end
