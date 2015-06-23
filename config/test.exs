use Mix.Config

{:ok, hostname} = :inet.gethostname 
hostname = List.to_string hostname

config :honeybadger,
  api_key: "at3stk3y",
  endpoint: "https://api.honeybadger.io",
  hostname: hostname,
  project_root: System.cwd
