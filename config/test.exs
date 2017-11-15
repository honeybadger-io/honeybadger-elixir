use Mix.Config

config :honeybadger,
  environment_name: :test,
  api_key: "abc123",
  origin: "http://localhost:4444",
  exclude_envs: []

config :ex_unit,
  assert_receive_timeout: 400,
  refute_receive_timeout: 200
