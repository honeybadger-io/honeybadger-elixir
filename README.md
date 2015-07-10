# honeybadger-elixir

Elixir client and Plug for :zap: [Honeybadger](https://www.honeybadger.io/).

## Installation

Add the Honeybadger package to `deps/1` in your application's `mix.exs` file and run `mix do deps.get, deps.compile`

```elixir
defp deps do
  [{:honeybadger, "~> 0.1"}]
end
```

## Configuration

By default we will use the environment variable `HONEYBADGER_API_KEY` to find your API key to the Honeybadger API. If you would like to specify your key a different way, you can do so in the `config.exs` (or any `config/{{env}}.exs` file):

```elixir
config :honeybadger,
  api_key: "sup3rs3cr3tk3y"
```

You can also pass `hostname`, `origin`, and `api_origin` keys to `config`. Honeybadger uses these settings to add helpful information to exception reports. These settings default to `:inet.gethostname/0`, `System.cwd/0` and `https://api.honeybadger.io` respectively.

## Usage

The Honeybadger package can be used as a Plug alongside your Phoenix applications as well as a standlone client for sprinkling in exception notifications where they are needed.

## Phoenix and Plug

The Honeybadger Plug adds a [Plug.ErrorHandler](https://github.com/elixir-lang/plug/blob/master/lib/plug/error_handler.ex) to your pipeline. Simply `use` the `Honeybadger.Plug` module inside of a Plug, Phoenix.Controller or Phoenix.Router and any crashes will be automatically reported to Honeybadger.

```elixir
defmodule MyPlugApp do
  use Plug.Router
  use Honeybadger.Plug
  
  [... the rest of your plug ...]
end

defmodule MyPhoenixApp.PageController do
  use MyPhoenixApp.Web, :controller
  use Honeybadger.Plug
  
  [... the rest of your controller actions ...]
end

defmodule MyPhoenixApp.Router do
  use Crywolf.Web, :router
  use Honeybadger.Plug
  
  pipeline :browser do
    [...]
  end
end
```

## Standalone Client

Use `Honeybadger.notify/3` to send exception information to the collector API. The first parameter is the exception, the second parameter is the context/metadata and the third paramter is the stacktrace. The stacktrace defaults to the stacktrace of the current process.

```elixir
try do
  File.read! "this_file_really_should_exist_dang_it.txt"
rescue
  exception ->
    context = %{user_id: 5, account_name: "Foo"}
    Honeybadger.notify(exception, context)
end
```