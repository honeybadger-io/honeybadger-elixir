use Mix.Config

config :logger, backends: [:console, Honeybadger.Logger]
