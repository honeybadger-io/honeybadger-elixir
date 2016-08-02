# Honeybadger-Elixir Changelog

## v0.6.1

Reformatting the plug environment data sent to Honeybadger.

## v0.6.0

This release removes warnings for Elixir 1.3.0 and covers v1.4.0-dev as of
2016-07-22. There was also a switch to using `:native` `FromUnits` to match
the `Plug.Logger` usage of `:erlang.convert_time_unit`. This maintains
consistency between `Honeybadger.Logger` and `Plug.Logger`.

## v0.5.0

Honeybadger now collects successful response times, aggregates them and sends
them to the Honeybadger API! You can see request metric data from the metrics
tab on Honeybadger.io!

## v0.4.0

Due to the `Mix.env/0` function always being set to `prod` for dependencies and
Mix being compiled out of applications by exrm, we now require you to
explicitly declare your `environment_name` for every environment in your
`config.exs` files.

  Example:
    # config/dev.exs
    config :honeybager, environment_name: :dev

Doing this will ensure you get accurate environment information for exceptions
that happen at runtime as well as compile time. You can also set the
`environment_name` setting a `MIX_ENV` environment variable.

  Example:
  $ MIX_ENV=prod mix phoenix.server

**Note:** setting `environment_name` in your config files takes higher
precedence than the `MIX_ENV` environment variable.

## v0.3.1

  * Fix a bug where notifications reported by the `error_logger` were not
    sending the the context
