# Changelog

All notable changes to this project will be documented in this file. See [Keep a
CHANGELOG](http://keepachangelog.com/) for how to update this file. This project
adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
### Changed
- Update the minimum Elixir version to 1.10 (#390). Phoenix v1.5.11 causes a compilation error due to the new `mime` dependency, which requires Elixir 1.10+.

##### NB: Due to the upgrade of phoenix from v1.5.10 to v1.5.11 you must be on Elixir 1.10+

## [v0.17.0] - 2021-08-16
### Fixed
- fix callback spec arg type mismatch for handle_errors/2 from plugs (#384)

### Changed
- Default `filter_args` to `false` (#375)

### Added
- Make notification for `Logger.error` configurable (#380, @yukster)

## [v0.16.4] - 2021-07-13
### Fixed
- Show arguments in stacktrace for `FunctionClauseError` when `filter_args = false` (#123, #373)

## [v0.16.3] - 2021-07-05
### Fixed
- Handle `extra_info` with `error_info` in `Honeybadger.Backtrace.format_line` (#369, @abstractcoder)
- Prevent infinite loop with `use_logger: true` when logging internal errors (#370)

## [v0.16.2] - 2021-04-27
### Fixed
- Encode notice message iodata before json serialize (#361)

## [v0.16.1] - 2021-04-12
### Fixed
- Call custom `filter_cgi_data/1` in `NoticeFilter` (#353)

## [v0.16.0] - 2021-02-22
### Changed
- Send notifications on error-level logs
- Added `ignored_domain` config with `[:cowboy]` as default

## [v0.15.0] - 2020-09-24
### Added
- New fingerprint option and config for `Honeybadger.notify/2`. Thanks @brunozrk! (#305)

## [v0.14.1] - 2020-07-06
### Fixed
- Implement Jason.Encoder for RingBuffer (#294)

## [v0.14.0] - 2020-03-12
### Changed
- Breadcrumbs on by default

## [v0.13.1] - 2020-02-06
### Fixed
- Safely sanitize invalid binaries when encoding JSON for notices.
- Fixes for Elixir 1.10 release (#259)

## [v0.13.0] - 2019-10-02
### Added
- Introducing Breadcrumbs (#235)! After enabling in the config with
  `breadcrumbs_enabled: true`, just call `Honeybadger.add_breadcrumb/2`
  anywhere in your code and if an error is reported in that process, the
  breadcrumb event will be passed along with the Notice.

### Changed
- Renamed Notifier to `honeybadger-elixir` and added language

## [v0.12.1] - 2019-06-12
### Fixed
- Call `Exception.blame/3` after normalizing string errors, which prevents
  reporint all string messages as Erlang errors. (#225)

## [v0.12.0] - 2019-05-30
### Added
- Added `:revision` configuration option
- Automatically call `Exception.blame/3` to record additional information in the exception

## [v0.11.0] - 2019-02-28
When upgrading to v0.11, users should be aware of a few important changes:

- You must be on Elixir 1.7+ and Erlang/OTP 21+
- Due to the deprecation of `System.stacktrace/0` and the introduction of [`__STACKTRACE__`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#__STACKTRACE__/0), manually calling `Honeybadger.notify/3` will no longer include a stacktrace by default. See the [issue discussion](https://github.com/honeybadger-io/honeybadger-elixir/pull/204) for more details
- A stacktrace can be manually provided from within a rescue/catch block via the __STACKTRACE__ macro, e.g. `Honeybadger.notify(SomeError, %{my: :context}, __STACKTRACE__)`

### Changed
- Switch from Erlang's `:error_logger` to an Elixir 1.7 and Erlang/OTP 21+
  `Logger` backend. This provides more consistent error reporting and enhanced
  integration with Logger metadata.
- Stop automatically extracting stacktraces for calls to `Honeybadger.notice/3`.
  The generated stacktrace was unreliably and frequently listed the Honeybadger
  reporter's internals, rather than application code. Manual calls to `notice/3`
  should happen within a `rescue/catch` block and use the `__STACKTRACE__`
  macro.

### Added
- Use `Logger.metadata` as the basis for Honeybadger context in all logger
  generated notices

### Fixed
- Fix Map.t() isn't a valid dialyzer type (#198)
- Try to convert remote IP to string in case of parsing failure

## [v0.10.3] - 2018-07-02
### Fixed
- Prevent crashes reporting `:badmatch` when fetching the current stacktrace
  from a dead process.
- Updated dependencies.

## [v0.10.2] - 2018-07-02
### Fixed
- Fix crashes caused by presence of structs in the context.

## [v0.10.1] - 2018-06-27
### Changed
- Handle fetching peer info when using Plug 1.6. This is implemented in a
  backward compatible manner, so versions < 1.6 will continue to work.

### Fixed
- Fetch peer information for multiple plug versions
- Bump phoenix from 1.3.2 to 1.3.3
- Bump hackney from 1.12.1 to 1.13.0

## [v0.10.0] - 2018-05-29
### Changed
- Replace Poison with Jason for JSON encoding.
- Reduce the log level used for dev mode warning.
- Update dependenices.

### Fixed

  JSON encoding error.
- Send notifications even when the stacktrace isn't a list. Errors reported from
  the error logger can occasionally have a malformed stacktrace, which would
  raise another exception and prevent the notification from being sent.

## [v0.9.0] - 2018-03-21
### Changed
- Use lazy logging within `Honeybadger.Client`, this allows compile time purging
  when the log level is set higher.
### Fixed
- Fix a regression which was causing `Not Found (404)` errors to be reported.
- Fix an issue caused by hackney because of unread response bodies.

## [v0.8.0] - 2018-01-17
### Added
- Include function arity in notice backtraces. For example, the reported method
  would be `notify/3` instead of `notify`.
- Include function arguments in notice backtraces. This is disabled by default,
  and can be enabled by setting `filter_args` to `false` in configuration.

### Changed
- Allow `handle_errors` from `Honeybadger.Plug` to be overridden.

### Fixed
- Safely convert binary `:environment_name` values to an atom. If the
  environment was specified via `{:system, "HONEYBADGER_ENV"}` and the
  `HONEYBADGER_ENV` value didn't already exist as an atom the app would fail to
  boot.
- Ignore the absence of `HONEYBADGER_API_KEY` when running in an excluded env


## [v0.7.0] - 2017-11-07
### Added
- Increases the logging around client activity
  (honeybadger-io/honeybadger-elixir#20).
- Explicitly allow sending notices with strings and maps. For example, it is now
  possible to send a `RuntimeError` by calling `Honeybadger.notify("oops!")`.
- Added Honeybadger test mix task which can be invoked using `mix honeybadger.test`

### Changed
- Switch from `GenEvent` to implementing `gen_event` behaviour.
- Remove `error_logger` backend on application stop.
- Use the latest exception's stacktrace whenever `notify` is called from a
  `try` expression.
- Namespace modules related to `Filter` and `NoticeFilter`. This is largely an
  internal restructuring, but any custom filters that used the
  `Honeybadger.FilterMixin` will need to specify `Honeybadger.Filter.Mixin`
  instead.
- Drops `HTTPoison` in favor of directly using `Hackney`, which gives us access to
  a connection pool.
- Drops Meck and stubbing in favor of a local cowboy server
  (honeybadger-io/honeybadger-elixir#7).
- Starts a supervision tree with the client as a child.
- Report the controller and action name as component and action for phoenix apps

### Fixed
- Filtering CGI data now respects the `filter_disable_url` setting. All path
  related fields (`ORIGINAL_FULLPATH`, `QUERY_STRING`, `PATH_INFO`) are filtered
  now.
- Get the environment directly from `Mix.env` and always compare the environment
  names as atoms (honeybadger-io/honeybadger-elixir#94).
- Changes notify from a macro to a function.
- Stops spawning new tasks for every error, instead relying on async handling in
  the client (honeybadger-io/honeybadger-elixir#88).

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
