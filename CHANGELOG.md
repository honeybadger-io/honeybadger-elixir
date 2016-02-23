# Honeybadger-Elixir Changelog

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
