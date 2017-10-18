# Changelog
All notable changes to this project will be documented in this file. See [Keep a
CHANGELOG](http://keepachangelog.com/) for how to update this file. This project
adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Added
- Increases the logging around client activity
  (honeybadger-io/honeybadger-elixir#20).
- Explicitly allow sending notices with strings and maps. For example, it is now
  possible to send a `RuntimeError` by calling `Honeybadger.notify("oops!")`.

### Changed
- Use the latest exception's stacktrace whenever `notify` is called from a
  `try` expression.

### Fixed
- Get the environment directly from `Mix.env` and always compare the environment
  names as atoms (honeybadger-io/honeybadger-elixir#94).
- Drops HTTPoison in favor of directly using Hackney, which gives us access to a
  connection pool.
- Drops Meck and stubbing in favor of a local cowboy server
  (honeybadger-io/honeybadger-elixir#7).
- Changes notify from a macro to a function.
- Stops spawning new tasks for every error, instead relying on async handling in
  the client (honeybadger-io/honeybadger-elixir#88).
- Starts a supervision tree with the client as a child.

## [0.6.3] - 2017-05-04
### Changed
- Removes metrics reporting.

### Fixed
- Loosens httpoison dependency.
- Misc. bug fixes.

## [0.6.2] - 2016-10-24
### Added
- ability to customize error names/messages,

### Fixed
- stops plug error notifications from being sent twice
- minor typo fixes
- dependency updates

## [0.6.1] - 2016-08-02
### Fixed
- Reformatting the plug environment data sent to Honeybadger.

## [0.6.0] - 2016-07-22
### Fixed
- This release removes warnings for Elixir 1.3.0 and covers v1.4.0-dev as of
  2016-07-22. There was also a switch to using `:native` `FromUnits` to match
  the `Plug.Logger` usage of `:erlang.convert_time_unit`. This maintains
  consistency between `Honeybadger.Logger` and `Plug.Logger`.

## [0.5.0] - 2016-04-26
### Added
- Honeybadger now collects successful response times, aggregates them and sends
  them to the Honeybadger API! You can see request metric data from the metrics
  tab on Honeybadger.io!

## [0.4.0] - 2016-02-23
### Changed
- Due to the `Mix.env/0` function always being set to `prod` for dependencies and
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

## [0.3.1] - 2016-02-04
### Fixed
- Fix a bug where notifications reported by the `error_logger` were not
  sending the the context
