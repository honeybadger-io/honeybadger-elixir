# Honeybadger for Elixir

![Elixir CI](https://github.com/honeybadger-io/honeybadger-elixir/workflows/Elixir%20CI/badge.svg?branch=master)

Elixir Plug, Logger and client for the :zap: [Honeybadger error notifier](https://www.honeybadger.io/).

**Upgrading to v0.11?** [See the release notes](https://github.com/honeybadger-io/honeybadger-elixir/blob/master/CHANGELOG.md#v0110---2019-02-28)

## Getting Started

[<img src="https://docs-honeybadger.s3.amazonaws.com/elixirsips.jpg" alt="ElixirSips" width=600/>](https://honeybadger.wistia.com/medias/krtqjywtp3)

[Watch our screencast](https://honeybadger.wistia.com/medias/krtqjywtp3) by Josh Adams of [ElixirSips](http://elixirsips.com/)!

### Version Requirements

- Erlang >= 24.0
- Elixir >= 1.15
- Plug >= 1.10
- Phoenix >= 1.0 (This is an optional dependency and the version requirement applies only if you are using Phoenix)

### 1. Install the package

Add the Honeybadger package to `deps/0` in your
application's `mix.exs`:

```elixir
defp deps do
  [{:honeybadger, "~> 0.22"}]
end
```

Then run:

```sh
mix do deps.get, deps.compile
```

### 2. Set your API key and environment name

By default, the environment variable `HONEYBADGER_API_KEY` will be used to
report errors to the Honeybadger API:

```sh
export HONEYBADGER_API_KEY={{PROJECT_API_KEY}}
```

You can alternatively configure Honeybadger settings in `config.exs`:

```elixir
config :honeybadger,
  api_key: "{{PROJECT_API_KEY}}"
```

We also need to set the name of the environment for each environment. This
ensures that we can accurately report the environment that an error occurs in.
You can add something like the following to each of your `#{env}.exs` files:

```elixir
config :honeybadger,
  environment_name: :dev
```

If `environment_name` is not set we will fall back to the value of `Mix.env()`.
`Mix.env()` uses the atomized value of the `MIX_ENV` environment variable and
defaults to `:prod` when the environment variable is not set. This should be good
for most setups. If you want to have an `environment_name` which is different than
the `Mix.env()`, you should set `environment_name` in your `config.exs` files for each
environment. This ensures that we can give you accurate environment information
even during compile time. Explicitly setting the `environment_name` config
takes higher precedence over the `Mix.env()` value.

### 3. Report a test error

-> **Note:** Honeybadger does not report errors in `dev` and `test` environments by default. To enable reporting in development environments, temporarily add `exclude_envs: []` to your Honeybadger config.

To report a test error to Honeybadger, fire up `iex -S mix`, then run:

```elixir
Honeybadger.notify("Hello Elixir!")
```

After you've tested your Honeybadger installation, you may want to configure one or more of the following integrations to automatically report errors.

### 4. Enable automatic error reporting

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

##### Phoenix app

```elixir
defmodule MyPhoenixApp.Router do
  use Crywolf.Web, :router
  use Honeybadger.Plug

  pipeline :browser do
    [...]
  end
end
```

##### Plug app

```elixir
defmodule MyPlugApp do
  use Plug.Router
  use Honeybadger.Plug

  [... the rest of your plug ...]
end
```

#### Logger

Just set the `use_logger` option to `true` in your application's `config.exs`
and you're good to go:

```elixir
config :honeybadger,
  use_logger: true
```

Any
[SASL](http://www.erlang.org/doc/apps/sasl/error_logging.html) compliant
processes that crash will send an error report to the `Honeybadger.Logger`.
After the error reaches the logger we take care of notifying Honeybadger for
you!

#### Manual reporting

You can manually report rescued exceptions with the  `Honeybadger.notify` function.

```elixir
try do
  File.read! "this_file_really_should_exist_dang_it.txt"
rescue
  exception ->
    Honeybadger.notify(exception, metadata: %{}, stacktrace: __STACKTRACE__, fingerprint: "")
end
```

## Insights Automatic Instrumentation

Honeybadger Insights allows you to automatically track various events in your
application. To enable Insights automatic instrumentation, add the following to
your configuration:

```elixir
config :honeybadger,
  insights_enabled: true
```

### Supported Libraries

Honeybadger automatically instruments the following libraries when they are available:

* Absinthe: GraphQL query execution
* Ecto: Database queries
* Finch: HTTP client requests, often used by other libraries like Req
* Tesla: HTTP client requests
* LiveView: Phoenix LiveView lifecycle events
* Oban: Background job processing
* Plug/Phoenix: HTTP requests

### Custom Configuration

Each library can be configured individually using the `insights_config` option:

```elixir
config :honeybadger, insights_config: %{
  # Ecto configuration
  ecto: %{
    # A list of strings or regex patterns of queries to exclude
    excluded_queries: [~r/^(begin|commit)/i],

    # A list of table/source names to exclude
    excluded_sources: ["schema_migrations"]
  },

  # Finch/Tesla configuration
  finch: %{
    # Include full URLs instead of just hostnames
    full_url: false
  },

  # Plug configuration
  plug: %{
    telemetry_events: [[:phoenix, :endpoint, :stop]]
  },

  # LiveView configuration
  live_view: %{
    telemetry_events: [
      [:phoenix, :live_view, :mount, :stop],
      [:phoenix, :live_view, :update, :stop]
    ]
  },

  # Absinthe configuration
  absinthe: %{
    telemetry_events: [
      [:absinthe, :execute, :operation, :start],
      [:absinthe, :execute, :operation, :stop],
      [:absinthe, :execute, :operation, :exception]
    ]
  },

  # Oban configuration
  oban: %{
    telemetry_events: [
      [:oban, :job, :stop],
      [:oban, :job, :exception]
    ]
  }
}
```

### Event Filtering

You can filter out or customize events sent to Honeybadger Insights by
using the `Honeybadger.EventFilter.Mixin` module. You can customize both
the event built from telemetry data (`filter_telemetry_event/3`) and the event
right before it is sent to Honeybadger (`filter_event/1`):

```elixir
defmodule MyApp.MyFilter do
  use Honeybadger.EventFilter.Mixin

  # Drop analytics events by returning nil
  def filter_event(%{event_type: "analytics"} = _event), do: nil

  # Anonymize user data in login events
  def filter_event(%{event_type: "login"} = event) do
    event
    |> update_in([:data, :user_email], fn _ -> "[REDACTED]" end)
    |> put_in([:metadata, :filtered], true)
  end

  # For telemetry events, you can customize while still applying default filtering
  def filter_telemetry_event(data, raw, event) do
    # First apply default filtering
    filtered_data = apply_default_telemetry_filtering(data)

    # Then apply custom logic
    case event do
      [:auth, :login, :start] ->
        Map.put(filtered_data, :security_filtered, true)
      _ ->
        filtered_data
    end
  end

  # Keep all other events as they are
  def filter_event(event), do: event
end
```

Then configure the filter in your application's configuration:

```elixir
config :honeybadger, event_filter: MyApp.EventFilter
```

### Event Context

You can add custom metadata to the events sent to Honeybadger Insights by
using the `event_context/1` function. This metadata will be included in each
event call within the same process.

Note: This will add the metadata to all events sent, so be careful not to
include too much data. Try to keep it to simple key/value pairs.

For example, you can add user ID information to all events (via plug):

```elixir
defmodule MyAppWeb.Plug.UserContext do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user = get_session(conn, :user)
    Honeybadger.event_context(%{user_id: user.id})
    conn
  end
end
```

Event context is not automatically propagated to other processes. If you want to
add context to events in a different process, you can use the
`Honeybadger.event_context/0` function to get the current context and pass it
to the `Honeybadger.event/1` function:

```elixir
defmodule MyApp.MyGenServer do
  use GenServer

  def set(value) do
    GenServer.cast(__MODULE__, {:set, value, Honeybadger.event_context()})
  end

  def handle_cast({:set, value, hb_context}, _state) do
    Honeybadger.event_context(hb_context)

    Honeybadger.event("set_value", %{value: value})
    {:noreply, value}
  end
end
```

If you know the parent process is alive and part of the process tree, you can
use `Honeybadger.inherit_event_context/0` to inherit the context from the
parent process. This method works best if you are running OTP 25+.

```elixir
Task.async(fn ->
  Honeybadger.inherit_event_context()
  # Do some work here
  Honeybadger.event("work", %{did: "some_work"})
end)
```

Scenarios when inheriting context is useful include:

- Direct process spawning (`spawn`, `spawn_link`)
- `Task.async/1`, `Task.await/1`, etc.
- Other scenarios where direct parent-child relationships are maintained

When explicit passing is needed:

- GenServer
- Supervised processes
- Processes started through other OTP abstractions

### Event Sampling

You can enable event sampling to reduce the number of events sent to
Honeybadger. This is especially useful if you are hitting your daily event
quota limit:

```elixir
config :honeybadger,
  # Sample 50% of events
  insights_sample_rate: 50
```

The `insights_sample_rate` option accepts a whole percentage value between 0
and 100, where 0 means no events will be sent and 100 means all events will be
sent. The default is no sampling (100%).

Events are sampled by hashing the `request_id` if available in the event payload,
otherwise random sampling is used. This deterministic approach ensures that
related events from the same request are consistently sampled together.

The sample rate is applied to all events sent to Honeybadger Insights, including
automatic instrumentation events. You can also set the sample rate per event
by adding the `sample_rate` key to the event metadata map:

```elixir
Honeybadger.event("user_created", %{
  user_id: user.id,
  _hb: %{sample_rate: 100}
})
```

The event sample rate can also be set within the `event_context/1` function.
This can be handy if you want to set an overall sample rate for a process or
ensure that specific instrumented events get sent:

```elixir
# Set a higher sampling rate for this entire process
Honeybadger.event_context(%{_hb: %{sample_rate: 100}})

# Now all events from this process, including automatic instrumentation,
# will use the 100% sample rate
Ecto.Repo.insert!(%MyApp.User{}) # This instrumented event will be sent
```

Remember that context is process-bound and applies to all events sent from the
same process after the `event_context/1` call, until it's changed or the process
terminates.

When setting sample rates below the global setting, be aware that this affects
how events with the same `request_id` are sampled. Since sampling is
deterministic based on the `request_id` hash, all events sharing the same
`request_id` will either all be sampled or all be skipped together. This
ensures consistency across related events.

With that in mind, it's recommended to default to the global sample rate and
use per-event sampling for specific cases where you want to ensure events are
sent regardless of the global setting, or you are setting the sample rate in
the context where all events with the same `request_id` will also share the
same sampling rate.


## Breadcrumbs

Breadcrumbs allow you to record events along a processes execution path. If
an error is thrown, the set of breadcrumb events will be sent along with the
notice. These breadcrumbs can contain useful hints while debugging.

Breadcrumbs are stored in the logger context, referenced by the calling
process. If you are sending messages between processes, breadcrumbs will not
transfer automatically. Since a typical system might have many processes, it
is advised that you be conservative when storing breadcrumbs as each
breadcrumb consumes memory.

### Automatic Breadcrumbs

We leverage the `telemetry` library to automatically create breadcrumbs from
specific events.

__Phoenix__

If you are using `phoenix` (>= v1.4.7) we add a breadcrumb from the router
start event.

__Ecto__

We can create breadcrumbs from Ecto SQL calls if you are using `ecto_sql` (>=
v3.1.0). You also must specify in the config which ecto adapters you want to
be instrumented:

```elixir
config :honeybadger,
  ecto_repos: [MyApp.Repo]
```

## Sample Application

If you'd like to see the module in action before you integrate it with your apps, check out our [sample Phoenix application](https://github.com/honeybadger-io/crywolf-elixir).

You can deploy the sample app to your Heroku account by clicking this button:

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/honeybadger-io/crywolf-elixir)

Don't forget to destroy the Heroku app after you're done so that you aren't
charged for usage.

The code for the sample app is [available on Github](https://github.com/honeybadger-io/crywolf-elixir), in case you'd like to read through it, or run it locally.

## Filtering Sensitive Data

Before data is sent to Honeybadger, it is passed through a filter to remove sensitive fields and do other processing on the data.  The default configuration is equivalent to:

```elixir
config :honeybadger,
  filter: Honeybadger.Filter.Default,
  filter_keys: [:password, :credit_card]
```

This will remove any entries in the `context`, `session`, `cgi_data` and `params` that match one of the filter keys.  The filter is case insensitive and matches atoms or strings.

If `Honeybadger.Filter.Default` does not suit your needs, you can implement your own filter. See the `Honeybadger.Filter.Mixin` module doc for details on implementing your own filter.

## Filtering Arguments

Honeybadger can show arguments in the stacktrace for `FunctionClauseError` exceptions. To enable argument reporting, set `filter_args` to `false`:

```elixir
config :honeybadger, filter_args: false
```

## Excluding Errors

By default Honeybadger will be notified when an error occurs. To override this configuration in order not to send out errors to Honeybadger, set `exclude_errors` option in `config/config.exs`.

This can be done by passing a list of errors to be excluded:

```elixir
config :honeybadger,
  exclude_errors: ["RuntimeError"]
```

or

```elixir
config :honeybadger,
  exclude_errors: [RuntimeError]
```
Also you can implement the `Honeybadger.ExcludeErrors` behaviour function `exclude_error?/1`, which receives the full `Honeybadger.Notice` and returns a boolean signalling the error exclusion or not.

```elixir

  defmodule ExcludeFunClauseErrors do
    alias Honeybadger.ExcludeErrors

    @behaviour ExcludeErrors

    @impl ExcludeErrors

    def exclude_error?(notice) do
      notice.error.class == "FunctionClauseError"
    end
  end

```

```elixir
config :honeybadger,
  exclude_errors: ExcludeFunClauseErrors
```


## Customizing Error Grouping

See the [Error Monitoring Guide](https://docs.honeybadger.io/guides/errors/#error-grouping) for more information about how honeybadger groups similar exception together. You can customize the grouping for each exception in Elixir by sending a custom *fingerprint* when the exception is reported.

To customize the fingerprint for all exceptions that are reported from your app, use the `fingerprint_adapter` configuration option in `config.ex`:

```elixir
config :honeybadger, fingerprint_adapter: MyApp.CustomFingerprint
```

```elixir
 defmodule MyApp.CustomFingerprint do
  @behaviour Honeybadger.FingerprintAdapter

  def parse(notice) do
    notice.notifier.language <> "-" <> notice.notifier.name
  end
end
```

You can also customize the fingerprint for individual exceptions when calling `Honeybadger.notify`:

```elixir
Honeybadger.notify(%RuntimeError{}, fingerprint: "culprit_id-123")
```

## Advanced Configuration

You can set configuration options in `config.exs`. It looks like this:

```elixir
config :honeybadger,
  api_key: "{{PROJECT_API_KEY}}",
  environment_name: :prod
```

If you'd rather read, eg., `environment_name` from the OS environment, you can do like this:

```elixir
config :honeybadger,
  environment_name: {:system, "HONEYBADGER_ENV"},
  revision: {:system, "HEROKU_SLUG_COMMIT"}
```

_NOTE: This works only for the string options, and `environment_name`._

Here are all of the options you can pass in the keyword list:

| Name                      | Description                                                                                   | Default                                  |
| ------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------- |
| `app`                     | Name of your app's OTP Application as an atom                                                 | `Mix.Project.config[:app]`               |
| `api_key`                 | Your application's Honeybadger API key                                                        | `System.get_env("HONEYBADGER_API_KEY"))` |
| `environment_name`        | (required) The name of the environment your app is running in.                                | `:prod`                                  |
| `exclude_errors`          | Filters out errors from being sent to Honeybadger                                             | `[]`                                     |
| `exclude_envs`            | Environments that you want to disable Honeybadger notifications                               | `[:dev, :test]`                          |
| `hostname`                | Hostname of the system your application is running on                                         | `:inet.gethostname`                      |
| `origin`                  | URL for the Honeybadger API                                                                   | `"https://api.honeybadger.io"`           |
| `project_root`            | Directory root for where your application is running                                          | `System.cwd/0`                           |
| `revision`                | The project's git revision                                                                    | `nil`                                    |
| `filter`                  | Module implementing `Honeybadger.Filter` to filter data before sending to Honeybadger.io      | `Honeybadger.Filter.Default`             |
| `filter_keys`             | A list of keywords (atoms) to filter.  Only valid if `filter` is `Honeybadger.Filter.Default` | `[:password, :credit_card, :__changed__, :flash, :_csrf_token]` |
| `filter_args`             | If true, will remove function arguments in backtraces                                         | `true`                                   |
| `filter_disable_url`      | If true, will remove the request url                                                          | `false`                                  |
| `filter_disable_session`  | If true, will remove the request session                                                      | `false`                                  |
| `filter_disable_params`   | If true, will remove the request params                                                       | `false`                                  |
| `filter_disable_assigns`  | If true, will remove the live_view event assigns                                              | `false`                                  |
| `fingerprint_adapter`     | Implementation of FingerprintAdapter behaviour                                                |                                          |
| `notice_filter`           | Module implementing `Honeybadger.NoticeFilter`. If `nil`, no filtering is done.               | `Honeybadger.NoticeFilter.Default`       |
| `sasl_logging_only`       | If true, will notifiy for SASL errors but not Logger calls                                    | `true`                                   |
| `use_logger`              | Enable the Honeybadger Logger for handling errors outside of web requests                     | `true`                                   |
| `ignored_domains`         | Add domains to ignore Error events in `Honeybadger.Logger`.                                   | `[:cowboy]`                              |
| `breadcrumbs_enabled`     | Enable breadcrumb event tracking                                                              | `false`                                  |
| `ecto_repos`              | Modules with implemented Ecto.Repo behaviour for tracking SQL breadcrumb events               | `[]`                                     |
| `event_filter`            | Module implementing `Honeybadger.EventFilter`. If `nil`, no filtering is done.                | `Honeybadger.EventFilter.Default`        |
| `insights_enabled`        | Enable sending automatic events to Honeybadger Insights                                       | `false`                                  |
| `insights_config`         | Specific library Configuration for Honeybadger Insights.                                      | `%{}`                                    |
| `http_adapter`            | Module implementing `Honeybadger.HttpAdapter` to send data to Honeybadger.io                  | Any available adapter (`Req`, `hackney`) |
| `events_worker_enabled`   | Enable sending events in a separate process                                                   | `true`                                   |
| `events_max_batch_retries`| Maximum number of retries for sending events                                                  | `3`                                      |
| `events_batch_size`       | Maximum number of events to send in a single batch                                            | `1000`                                   |
| `events_max_queue_size`   | Maximum number of events to queue before dropping                                             | `10000`                                  |
| `events_timeout`          | Timeout in milliseconds for sending events                                                    | `5000`                                   |
| `events_throttle_wait`    | Time in milliseconds to wait before retrying a failed batch                                   | `60000`                                  |

### HTTP Adapters

The HTTP client used to send data to Honeybadger can be customized. We will use
either `Req` or `hackney` (in that order) by default if they are loaded. If you
want to use a different HTTP client, you can set the `http_adapter` configuration
option to any of our pre-built adapter modules.

```elixir
config :honeybadger,
  # Without options
  http_adapter: Honeybadger.HTTPAdapter.Hackney
  # With options
  http_adapter: {Honeybadger.HTTPAdapter.Hackney, [...]}
```

You can also implement your own HTTP adapter to send data to Honeybadger. The
adapter must implement the `Honeybadger.HttpAdapter` behaviour.

## Public Interface

### `Honeybadger.notify`: Send an exception to Honeybadger.

Use the `Honeybadger.notify/2` function to send exception information to the
collector API.  The first parameter is the exception and the second parameter
is the context/metadata/fingerprint. There is also a `Honeybadger.notify/1` which doesn't require the second parameter.

#### Examples:

```elixir
try do
  File.read! "this_file_really_should_exist_dang_it.txt"
rescue
  exception ->
    context = %{user_id: 5, account_name: "Foo"}
    Honeybadger.notify(exception, metadata: context, stacktrace: __STACKTRACE__)
end
```

---


### `Honeybadger.context/1`: Set metadata to be sent if an error occurs

`Honeybadger.context/1` is provided for adding extra data to the notification
that gets sent to Honeybadger. You can make use of this in places such as a Plug
in your Phoenix Router or Controller to ensure useful debugging data is sent along.

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

`Honeybadger.context/1` stores the context data in the process dictionary, so
it will be sent with errors/notifications on the same process. The following
`Honeybadger.notify/1` call will not see the context data set in the previous line.

```elixir
Honeybadger.context(user_id: 5)
Task.start(fn ->
  # this notify does not see the context set earlier
  # as this runs in a different elixir/erlang process.
  Honeybadger.notify(%RuntimeError{message: "critical error"})
end)
```

---

### `Honeybadger.add_breadcrumb/2`: Store breadcrumb within process

Appends a breadcrumb to the notice. Use this when you want to add some custom
data to your breadcrumb trace in effort to help debugging. If a notice is
reported to Honeybadger, all breadcrumbs within the execution path will be
appended to the notice. You will be able to view the breadcrumb trace in the
Honeybadger interface to see what events led up to the notice.

#### Examples:

```elixir
Honeybadger.add_breadcrumb("Email sent", metadata: %{
  user: user.id,
  message: message
})
```

---

### `Honeybadger.event`: Send an event to Honeybadger Insights.

Use the `Honeybadger.event/1` function to send event data to the events API. A
`ts` field with the current timestamp will be added to the data if it isn't
provided. You can also use `Honeybadger.event/2`, which accepts a string as the
first parameter and adds that value to the `event_type` field in the map before
being sent to the API.

#### Examples:

```elixir
Honeybadger.event(%{
  event_type: "user_created",
  user: user.id
})

Honeybadger.event("project_deleted", %{
  project: project.name
})
```

---

## Proxy configuration

If your server needs a proxy to access Honeybadger, add the following to your config

```elixir
config :honeybadger,
  proxy: "url",
  proxy_auth: {"username", "password"}
```

## Excluded environments

Honeybadger won't report errors from `:dev` and `:test` environments by default. To enable error reporting in dev:

1. Set the HONEYBADGER_API_KEY as documented above
2. Remove `:dev` from the `exclude_envs` by adding this to your config/dev.exs
```elixir
config :honeybadger,
  exclude_envs: [:test]
```
3. Run the `mix honeybadger.test` mix task task to simulate an error

## Changelog

See https://github.com/honeybadger-io/honeybadger-elixir/blob/master/CHANGELOG.md

## Contributing

If you're adding a new feature, please [submit an
issue](https://github.com/honeybadger-io/honeybadger-elixir/issues/new) as a
preliminary step; that way you can be (moderately) sure that your pull request
will be accepted.

### To contribute your code:

1. Fork it.
2. Create a topic branch `git checkout -b my_branch`
3. Commit your changes `git commit -am "Boom"`
4. Push to your branch `git push origin my_branch`
5. Send a [pull request](https://github.com/honeybadger-io/honeybadger-elixir/pulls)

### Publishing a release on hex.pm

#### Github Workflow

A new version can be published on Hex.pm using the Publish New Release workflow.
The workflow can be triggered manually from the Github Actions page and takes the following input:
- `version`: One of `patch`, `minor` or `major`. The version number will be bumped accordingly.
- `changes`: An entry to be added to the changelog.

#### Manual Release

Versioning, changelog generation and publishing to hex.pm is handled by the `mix expublish` task.
You can read more about it [here](https://github.com/ucwaldo/expublish).

1. `mix deps.get`
2. echo "CHANGELOG ENTRY" > RELEASE.MD
3. `mix expublish.[patch|minor|major]`

### License

This library is MIT licensed. See the
[LICENSE](https://raw.github.com/honeybadger-io/honeybadger-elixir/master/LICENSE)
file in this repository for details.
