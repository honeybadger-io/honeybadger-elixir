defmodule Honeybadger.ComponentDeriverTest do
  # Not async: these tests set the global :app config via with_config, which
  # would race with async tests in other modules that read it (e.g. Backtrace's
  # context depends on it).
  use Honeybadger.Case, async: false

  alias Honeybadger.ComponentDeriver

  # Use real Honeybadger modules for testing since Application.get_application/1
  # only works for modules that are part of a loaded OTP application.
  # Honeybadger.Notice, Honeybadger.Backtrace, etc. are part of :honeybadger app.

  describe "derive/2" do
    test "returns nil for empty stacktrace" do
      assert ComponentDeriver.derive([]) == nil
    end

    test "returns the first app module from stacktrace" do
      # Use real Honeybadger modules which are part of the :honeybadger app
      stacktrace = [
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]},
        {Honeybadger.Backtrace, :from_stacktrace, 1,
         [file: ~c"lib/honeybadger/backtrace.ex", line: 10]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end

    test "skips library modules that don't belong to the app" do
      stacktrace = [
        {Ecto.Repo, :insert, 2, [file: ~c"lib/ecto/repo.ex", line: 100]},
        {Ecto.Changeset, :apply_action!, 2, [file: ~c"lib/ecto/changeset.ex", line: 200]},
        {Postgrex.Protocol, :recv_message, 2, [file: ~c"lib/postgrex/protocol.ex", line: 100]},
        {DBConnection, :execute, 4, [file: ~c"lib/db_connection.ex", line: 100]},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end

    test "skips modules configured in :ecto_repos for the app" do
      # Honeybadger.Notice stands in for MyApp.Repo here: a module owned by the
      # app that appears in Ecto error stacktraces but doesn't indicate where
      # the error originated.
      stacktrace = [
        {Honeybadger.Notice, :insert, 2, [file: ~c"lib/honeybadger/notice.ex", line: 100]},
        {Honeybadger.Backtrace, :from_stacktrace, 1,
         [file: ~c"lib/honeybadger/backtrace.ex", line: 10]}
      ]

      with_config([app: :honeybadger, ecto_repos: [Honeybadger.Notice]], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Backtrace"
      end)
    end

    test "returns nil if no suitable module found" do
      stacktrace = [
        {Ecto.Repo, :insert, 2, [file: ~c"lib/ecto/repo.ex", line: 100]},
        {Postgrex.Protocol, :recv_message, 2, [file: ~c"lib/postgrex/protocol.ex", line: 50]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == nil
      end)
    end

    test "only considers modules from the configured app" do
      # Ecto.Changeset is from :ecto app, not :honeybadger, so should be skipped
      # for app matching (not just pattern matching)
      stacktrace = [
        {Ecto.Query, :from, 2, [file: ~c"lib/ecto/query.ex", line: 10]},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        # Ecto.Query is from :ecto app, not :honeybadger, so should fall through
        assert result == "Honeybadger.Notice"
      end)
    end

    test "accepts app option override" do
      stacktrace = [
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      # Use a non-existent app so nothing matches
      result = ComponentDeriver.derive(stacktrace, app: :nonexistent_app)
      assert result == nil
    end

    test "handles malformed stack frames gracefully" do
      stacktrace = [
        {:not_a_module, :foo, 1, []},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end
  end

  describe "skip_patterns/1" do
    test "has no built-in library patterns" do
      # Library modules (Ecto, Postgrex, etc.) are already excluded by the app
      # ownership check, so there are no default skip patterns for them.
      with_config([app: :honeybadger], fn ->
        patterns = ComponentDeriver.skip_patterns()
        refute Enum.any?(patterns, &Regex.match?(&1, "Ecto.Repo"))
        refute Enum.any?(patterns, &Regex.match?(&1, "Postgrex.Protocol"))
        refute Enum.any?(patterns, &Regex.match?(&1, "DBConnection"))
      end)
    end

    test "includes modules from the app's :ecto_repos config" do
      with_config([app: :honeybadger, ecto_repos: [MyApp.Repo]], fn ->
        patterns = ComponentDeriver.skip_patterns()
        assert Enum.any?(patterns, &Regex.match?(&1, "MyApp.Repo"))
        assert Enum.any?(patterns, &Regex.match?(&1, "MyApp.Repo.Preloader"))
      end)
    end

    test "repo patterns do not match modules sharing the repo's name as a prefix" do
      with_config([app: :honeybadger, ecto_repos: [MyApp.Repo]], fn ->
        patterns = ComponentDeriver.skip_patterns()
        refute Enum.any?(patterns, &Regex.match?(&1, "MyApp.Reports"))
        refute Enum.any?(patterns, &Regex.match?(&1, "MyApp.Repository"))
      end)
    end

    test "includes user-configured patterns" do
      with_config([component_deriver_skip_patterns: [MyApp.CustomInfra]], fn ->
        patterns = ComponentDeriver.skip_patterns()
        # The module atom MyApp.CustomInfra becomes "MyApp.CustomInfra" string pattern
        assert Enum.any?(patterns, &Regex.match?(&1, "MyApp.CustomInfra"))
      end)
    end

    test "accepts regex patterns in config" do
      with_config([component_deriver_skip_patterns: [~r/^MyApp\.Internal/]], fn ->
        patterns = ComponentDeriver.skip_patterns()
        assert Enum.any?(patterns, &Regex.match?(&1, "MyApp.Internal.Something"))
      end)
    end

    test "accepts string patterns in config" do
      with_config([component_deriver_skip_patterns: ["MyApp.Internal"]], fn ->
        patterns = ComponentDeriver.skip_patterns()
        assert Enum.any?(patterns, &Regex.match?(&1, "MyApp.Internal"))
        assert Enum.any?(patterns, &Regex.match?(&1, "MyApp.Internal.Cache"))
        refute Enum.any?(patterns, &Regex.match?(&1, "MyApp.InternalStuff"))
      end)
    end
  end
end
