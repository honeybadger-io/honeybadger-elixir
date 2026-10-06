# Honeybadger for Elixir

[![Elixir CI](https://github.com/honeybadger-io/honeybadger-elixir/workflows/Elixir%20CI/badge.svg?branch=master)](https://github.com/honeybadger-io/honeybadger-elixir/actions/workflows/elixir.yml)
[![Hex Version](https://img.shields.io/hexpm/v/honeybadger.svg)](https://hex.pm/packages/honeybadger)

This is the Elixir Plug, Logger, and client for integrating apps with the :zap: [Honeybadger Exception Notifier for Elixir and Phoenix](https://www.honeybadger.io/for/elixir/).

When an uncaught exception occurs, Honeybadger will POST the relevant data to the Honeybadger server specified in your environment. Honeybadger can also send automatic performance events from Phoenix, Ecto, Oban, and more to [Honeybadger Insights](https://docs.honeybadger.io/guides/insights/).

## Documentation and Support

For comprehensive documentation and support, [check out our documentation site](https://docs.honeybadger.io/lib/elixir/).

API documentation is available on [HexDocs](https://hexdocs.pm/honeybadger/).

## Changelog

The [CHANGELOG](CHANGELOG.md) is generated automatically as part of the release process, using [conventional commits](https://www.conventionalcommits.org/).

## Development

Pull requests are welcome. If you're adding a new feature, please [submit an issue](https://github.com/honeybadger-io/honeybadger-elixir/issues/new) as a preliminary step; that way you can be (moderately) sure that your pull request will be accepted.

### To contribute your code:

1. Fork it.
2. Create a topic branch `git checkout -b my_branch`
3. Commit your changes `git commit -am "feat: add a thing"`
4. Push to your branch `git push origin my_branch`
5. Send a [pull request](https://github.com/honeybadger-io/honeybadger-elixir/pulls)

PR titles must follow the [conventional commits](https://www.conventionalcommits.org/) format.

### Running the tests

```sh
mix deps.get
mix test
```

### Releasing

Releases are automated, using [GitHub Actions](.github/workflows/publish.yml):
- When a PR is merged on master, the [elixir.yml](.github/workflows/elixir.yml) workflow is executed, which runs the tests.
- The [publish.yml](.github/workflows/publish.yml) workflow uses [release-please](https://github.com/googleapis/release-please) to open or update a release PR with the suggested version bump and changelog, based on the commit messages.
  Note: Not all commit messages trigger a new release, for example, `chore: ...` will not trigger a release.
- When the release PR is merged, the [publish.yml](.github/workflows/publish.yml) workflow runs again, creates a GitHub release, and publishes the package to Hex.pm.

### License

This library is MIT licensed. See the [LICENSE](https://raw.github.com/honeybadger-io/honeybadger-elixir/master/LICENSE) file in this repository for details.
