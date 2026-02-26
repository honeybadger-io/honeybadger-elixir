defmodule Honeybadger.Mixfile do
  use Mix.Project

  @source_url "https://github.com/honeybadger-io/honeybadger-elixir"
  @version "0.24.1"

  def project do
    [
      app: :honeybadger,
      version: @version,
      elixir: "~> 1.11",
      consolidate_protocols: Mix.env() != :test,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: ["test.ci": :test],

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
      xref: [exclude: [Plug.Conn, Ecto.Changeset]],

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
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :public_key],
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
        exclude_errors: [],

        # Filters
        notice_filter: Honeybadger.NoticeFilter.Default,
        event_filter: Honeybadger.EventFilter.Default,
        filter: Honeybadger.Filter.Default,
        filter_keys: [:password, :credit_card, :__changed__, :flash, :_csrf_token],
        filter_args: false,
        filter_disable_url: false,
        filter_disable_params: false,
        filter_disable_assigns: true,
        filter_disable_session: false,

        # Insights
        insights_enabled: false,
        insights_sample_rate: 100.0,
        insights_config: %{},

        # Events
        events_worker_enabled: true,
        events_max_batch_retries: 3,
        events_batch_size: 1000,
        events_max_queue_size: 10000,
        events_timeout: 5000,
        events_throttle_wait: 60000
      ],
      mod: {Honeybadger, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.1", optional: true},
      {:req, "~> 0.5.0", optional: true},
      {:jason, "~> 1.0"},
      {:plug, ">= 1.0.0 and < 2.0.0", optional: true},
      {:ecto, ">= 2.0.0", optional: true},
      {:phoenix, ">= 1.0.0 and < 2.0.0", optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:process_tree, "~> 0.2.1"},

      # Dev dependencies
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},

      # Test dependencies
      {:ash, "~> 3.0", only: :test},
      {:plug_cowboy, ">= 2.0.0 and < 3.0.0", only: :test},
      {:test_server, "~> 0.1.18", only: [:test]}
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

  defp aliases do
    [
      "deps.ci": [
        "deps.get --only test",
        "cmd --cd dummy/mixapp mix deps.get --only test"
      ],
      "test.ci": [
        "test --raise",
        "cmd --cd dummy/mixapp mix test --raise"
      ]
    ]
  end
end
