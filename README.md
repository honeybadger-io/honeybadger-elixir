# Honeybadger for Elixir

[![Build Status](https://travis-ci.org/honeybadger-io/honeybadger-elixir.svg?branch=master)](https://travis-ci.org/honeybadger-io/honeybadger-elixir)

Elixir Plug, Logger and client for the :zap: [Honeybadger error notifier](https://www.honeybadger.io/).

## Getting Started

[<img src="http://docs-honeybadger.s3.amazonaws.com/elixirsips.jpg" alt="ElixirSips" width=600/>](https://josh-rubyist.wistia.com/medias/pggpan0f9j)

[Watch our screencast](https://josh-rubyist.wistia.com/medias/pggpan0f9j) by Josh Adams of [ElixirSips](http://elixirsips.com/)!

### 1. Install the package

Prerequistes: minimum of Elixir 1.0 and Erlang 18.0

Add the Honeybadger package to `deps/0` and `application/0` in your
application's `mix.exs` file and run `mix do deps.get, deps.compile`

```elixir
defp application do
 [applications: [:honeybadger, :logger]]
end

defp deps do
  [{:honeybadger, "~> 0.6"}]
end
```

### 2. Set your API key and environment name

By default the environment variable `HONEYBADGER_API_KEY` will be used to find
your API key to the Honeybadger API. If you would like to specify your key or
any other configuration options a different way, you can do so in `config.exs`:

```elixir
config :honeybadger,
  api_key: "sup3rs3cr3tk3y"
```

We also need to set the name of the environment for each environment. This
ensures that we can accurately report the environment that an error occurs in.
You can add something like the following to each of your `#{env}.exs` files:

```elixir
config :honeybadger,
  environment_name: :dev
```

If `environment_name` is not set we will fall back to the `MIX_ENV` environment
variable. If neither `MIX_ENV` or the `environment_name` config are set then
you will get an exception informing you to set one of them. It is preferred
that you set `environment_name` in your `config.exs` files for each
environment. This ensures that we can give you accurate environment information
even during compile time. Explicitly setting the `environment_name` config
takes higher precedence over the `MIX_ENV` environment variable.

### 3. Enable error reporting

The Honeybadger package can be used as a Plug alongside your Phoenix
applications, as a logger backend, or as a standalone client for sprinkling in
exception notifications where they are needed.

#### Phoenix and Plug

The Honeybadger Plug adds a
[Plug.ErrorHandler](https://github.com/elixir-lang/plug/blob/master/lib/plug/error_handler.ex)
to your pipeline. Simply `use` the `Honeybadger.Plug` module inside of a Plug
or Phoenix.Router and any crashes will be automatically reported to
Honeybadger. It's best to `use Honeybadger.Plug` **after the Router plugs** so that
exceptions due to non-matching routes are not reported to Honeybadger.

```elixir
defmodule MyPlugApp do
  use Plug.Router
  use Honeybadger.Plug

  [... the rest of your plug ...]
end

defmodule MyPhoenixApp.Router do
  use Crywolf.Web, :router
  use Honeybadger.Plug

  pipeline :browser do
    [...]
  end
end
```

#### Logger

Just set the `use_logger` option to `true` in your application's `config.exs`
and you're good to go! Any
[SASL](http://www.erlang.org/doc/apps/sasl/error_logging.html) compliant
processes that crash will send an error report to the `Honeybadger.Logger`.
After the error reaches the logger we take care of notifying Honeybadger for
you!

#### Manual reporting

You can manually report rescued exceptions with the  `Honeybadger.notify` macro.

```elixir
try do
  File.read! "this_file_really_should_exist_dang_it.txt"
rescue
  exception ->
    require Honeybadger
    Honeybadger.notify(exception)
end
```



## Sample Application

If you'd like to see the module in action before you integrate it with your apps, check out our [sample Phoenix application](https://github.com/honeybadger-io/crywolf-elixir).

You can deploy the sample app to your Heroku account by clicking this button:

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/honeybadger-io/crywolf-elixir)

Don't forget to destroy the Heroku app after you're done so that you aren't
charged for usage.

The code for the sample app is [available on Github](https://github.com/honeybadger-io/crywolf-elixir), in case you'd like to read through it, or run it locally.

## Advanced Configuration

You can set configuration options in `config.exs`. It looks like this:

```elixir
config :honeybadger,
  api_key: "sup3rs3cr3tk3y",
  environment_name: :prod
```

Here are all of the options you can pass in the keyword list:

| Name         | Description                                                               | Default |
|--------------|---------------------------------------------------------------------------|---------|
| api_key      | Your application's Honeybadger API key                                    | System.get_env("HONEYBADGER_API_KEY"))` |
| environment_name | (required) The name of the environment your app is running in.                   | nil |
| app          | Name of your app's OTP Application as an atom                             | Mix.Project.config[:app] |
| use_logger   | Enable the Honeybadger Logger for handling errors outside of web requests | true |
| exclude_envs | Environments that you want to disable Honeybadger notifications           | [:dev, :test] |
| hostname     | Hostname of the system your application is running on                     | :inet.gethostname |
| origin       | URL for the Honeybadger API                                               | "https://api.honeybadger.io" |
| project_root | Directory root for where your application is running                      | System.cwd |

## Public Interface

### `Honeybadger.notify`: Send an exception to Honeybadger.

Use the `Honeybadger.notify/2` macro to send exception information to the
collector API.  The first parameter is the exception and the second parameter
is the context/metadata. There is also a `Honeybadger.notify/1` which doesn't require the second parameter.

#### Examples:

```elixir
try do
  File.read! "this_file_really_should_exist_dang_it.txt"
rescue
  exception ->
    require Honeybadger
    context = %{user_id: 5, account_name: "Foo"}
    Honeybadger.notify(exception, context)
end
```

---


### `Honeybadger.context/1`: Set metadata to be sent if an error occurs

`Honeybadger.context/1` is provided for adding extra data to the notification that gets sent to Honeybadger. You can make use of this in places such as a Plug in your Phoenix Router or Controller to ensure useful debugging data is sent along.

#### Examples:

```elixir
def MyPhoenixApp.Controller
  use MyPhoenixApp.Web, :controller

  plug :set_honeybadger_context

  def set_honeybadger_context(conn, _opts) do
    user = get_user(conn)
    Honeybadger.context(user_id: user.id, account: user.account.name)
    conn
  end
end
```
---

## Changelog

See https://github.com/honeybadger-io/honeybadger-elixir/releases

## Contributing

If you're adding a new feature, please [submit an
issue](https://github.com/honeybadger-io/honeybadger-elixir/issues/new) as a
preliminary step; that way you can be (moderately) sure that your pull request
will be accepted.

### To contribute your code:

1. Fork it.
2. Create a topic branch `git checkout -b my_branch`
3. Commit your changes `git commit -am "Boom"`
3. Push to your branch `git push origin my_branch`
4. Send a [pull request](https://github.com/honeybadger-io/honeybadger-elixir/pulls)

### License

This library is MIT licensed. See the
[LICENSE](https://raw.github.com/honeybadger-io/honeybadger-elixir/master/LICENSE)
file in this repository for details.
