defmodule Honeybadger.EventContextTest do
  use ExUnit.Case, async: true

  alias Honeybadger.EventContext

  setup do
    # Clear event context before each test
    Process.delete(Honeybadger.EventContext)
    :ok
  end

  describe "get/0" do
    test "returns an empty map when no context exists" do
      assert EventContext.get() == %{}
    end

    test "returns the stored context" do
      context = %{user_id: 123, action: "test"}
      EventContext.replace(context)
      assert EventContext.get() == context
    end
  end

  describe "get/1" do
    test "returns nil when no context exists" do
      assert EventContext.get(:user_id) == nil
    end

    test "returns nil when key doesn't exist in context" do
      EventContext.replace(%{action: "test"})
      assert EventContext.get(:user_id) == nil
    end

    test "returns the value for the given key" do
      EventContext.replace(%{user_id: 123, action: "test"})
      assert EventContext.get(:user_id) == 123
    end
  end

  describe "merge/1" do
    test "with keyword list" do
      result = EventContext.merge(user_id: 123, action: "test")
      assert result == %{user_id: 123, action: "test"}
      assert EventContext.get() == %{user_id: 123, action: "test"}
    end

    test "with map" do
      result = EventContext.merge(%{user_id: 123, action: "test"})
      assert result == %{user_id: 123, action: "test"}
      assert EventContext.get() == %{user_id: 123, action: "test"}
    end

    test "merges with existing context" do
      Process.put(Honeybadger.EventContext, %{user_id: 123})
      result = EventContext.merge(%{action: "test"})
      assert result == %{user_id: 123, action: "test"}
      assert EventContext.get() == %{user_id: 123, action: "test"}
    end

    test "overwrites existing keys" do
      Process.put(Honeybadger.EventContext, %{user_id: 123, action: "old"})
      result = EventContext.merge(%{action: "new"})
      assert result == %{user_id: 123, action: "new"}
      assert EventContext.get() == %{user_id: 123, action: "new"}
    end
  end

  describe "replace/1" do
    test "with keyword list" do
      result = EventContext.replace(user_id: 123, action: "test")
      assert result == %{user_id: 123, action: "test"}
      assert EventContext.get() == %{user_id: 123, action: "test"}
    end

    test "with map" do
      result = EventContext.replace(%{user_id: 123, action: "test"})
      assert result == %{user_id: 123, action: "test"}
      assert EventContext.get() == %{user_id: 123, action: "test"}
    end

    test "replaces existing context" do
      Process.put(Honeybadger.EventContext, %{user_id: 123, other: "value"})
      result = EventContext.replace(%{action: "test"})
      assert result == %{action: "test"}
      assert EventContext.get() == %{action: "test"}
    end
  end

  describe "put_new/2" do
    test "adds key when it doesn't exist" do
      result = EventContext.put_new(:user_id, 123)
      assert result == %{user_id: 123}
      assert EventContext.get() == %{user_id: 123}
    end

    test "doesn't overwrite existing key" do
      Process.put(Honeybadger.EventContext, %{user_id: 123})
      result = EventContext.put_new(:user_id, 456)
      assert result == %{user_id: 123}
      assert EventContext.get() == %{user_id: 123}
    end

    test "with function that returns value" do
      expensive_function = fn -> 123 end
      result = EventContext.put_new(:user_id, expensive_function)
      assert result == %{user_id: 123}
      assert EventContext.get() == %{user_id: 123}
    end

    test "function is not called when key exists" do
      EventContext.replace(%{user_id: 123})

      # Use a reference to track if the function was called
      test_pid = self()

      expensive_function = fn ->
        send(test_pid, :function_was_called)
        456
      end

      result = EventContext.put_new(:user_id, expensive_function)
      assert result == %{user_id: 123}
      assert EventContext.get() == %{user_id: 123}

      # Verify the function was never called
      refute_received :function_was_called
    end
  end

  describe "inherit/0" do
    test "returns :not_found when no parent context exists" do
      # ProcessTree should return nil when there's no parent context
      # This is testing the default case when inherit() is called
      assert EventContext.inherit() == :not_found
      assert EventContext.get() == %{}
    end

    test "returns :already_initialized when context already exists" do
      EventContext.replace(%{user_id: 123})
      assert EventContext.inherit() == :already_initialized
    end

    test "inherits parent context" do
      parent_context = Honeybadger.EventContext.merge(%{user_id: 123, action: "test"})
      test_pid = self()

      Task.async(fn ->
        # Simulate a child process inheriting the context
        EventContext.inherit()
        send(test_pid, {:context, EventContext.get()})
      end)

      receive do
        {:context, spawn_context} ->
          assert parent_context == spawn_context
      after
        1000 -> flunk("Test timed out")
      end
    end
  end

  # Test integration with Honeybadger module
  describe "integration with Honeybadger module" do
    test "Honeybadger.event_context/0 calls EventContext.get/0" do
      context = %{user_id: 123, action: "test"}
      Process.put(Honeybadger.EventContext, context)
      assert Honeybadger.event_context() == context
    end

    test "Honeybadger.event_context/1 calls EventContext.merge/1" do
      result = Honeybadger.event_context(%{user_id: 123})
      assert result == %{user_id: 123}
      assert EventContext.get() == %{user_id: 123}
    end

    test "Honeybadger.clear_event_context/0 clears the context" do
      Honeybadger.event_context(%{user_id: 123})
      assert Honeybadger.event_context() == %{user_id: 123}

      Honeybadger.clear_event_context()
      assert Honeybadger.event_context() == %{}
    end
  end
end
