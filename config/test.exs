use Mix.Config

config :honeybadger,
  api_key: "at3stk3y",
  hostname: Honeybadger.Mixfile.hostname,
  origin: "https://api.honeybadger.io",
  project_root: System.cwd
