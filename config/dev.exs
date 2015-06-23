use Mix.Config

{:ok, hostname} = :inet.gethostname 
hostname = List.to_string hostname

config :honeybadger,
  api_key: System.get_env("HONEYBADGER_API_KEY"),
  endpoint: "https://api.honeybadger.io",
  hostname: hostname,
  project_root: System.cwd
