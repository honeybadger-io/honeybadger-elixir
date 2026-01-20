defmodule Honeybadger.ComponentDeriverTest do
  use Honeybadger.Case, async: true

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
        {Honeybadger.Backtrace, :from_stacktrace, 1, [file: ~c"lib/honeybadger/backtrace.ex", line: 10]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end

    test "skips Ecto.Repo modules" do
      stacktrace = [
        {Ecto.Repo, :insert, 2, [file: ~c"lib/ecto/repo.ex", line: 100]},
        {Ecto.Repo.Queryable, :all, 3, [file: ~c"lib/ecto/repo/queryable.ex", line: 50]},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end

    test "skips Ecto.Changeset modules" do
      stacktrace = [
        {Ecto.Changeset, :apply_action!, 2, [file: ~c"lib/ecto/changeset.ex", line: 200]},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end

    test "skips Postgrex modules" do
      stacktrace = [
        {Postgrex.Protocol, :recv_message, 2, [file: ~c"lib/postgrex/protocol.ex", line: 100]},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
      end)
    end

    test "skips DBConnection modules" do
      stacktrace = [
        {DBConnection, :execute, 4, [file: ~c"lib/db_connection.ex", line: 100]},
        {Honeybadger.Notice, :new, 4, [file: ~c"lib/honeybadger/notice.ex", line: 42]}
      ]

      with_config([app: :honeybadger], fn ->
        result = ComponentDeriver.derive(stacktrace)
        assert result == "Honeybadger.Notice"
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

  describe "skip_patterns/0" do
    test "includes default patterns" do
      patterns = ComponentDeriver.skip_patterns()
      assert Enum.any?(patterns, &Regex.match?(&1, "Ecto.Repo"))
      assert Enum.any?(patterns, &Regex.match?(&1, "Ecto.Repo.Queryable"))
      assert Enum.any?(patterns, &Regex.match?(&1, "Ecto.Changeset"))
      assert Enum.any?(patterns, &Regex.match?(&1, "Postgrex.Protocol"))
      assert Enum.any?(patterns, &Regex.match?(&1, "DBConnection"))
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
      end)
    end
  end
end
