import Config

config :honeybadger,
  environment_name: :test,
  api_key: "abc123",
  origin: "http://localhost:4444",
  events_worker_enabled: false
