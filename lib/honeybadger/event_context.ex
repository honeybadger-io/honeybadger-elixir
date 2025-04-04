defmodule Honeybadger.EventContext do
  @moduledoc false

  @key __MODULE__

  @doc """
  Merge the given map or keyword list into the current event context.
  """
  @spec merge(map() | list()) :: map()
  def merge(kw) when is_list(kw), do: merge(Map.new(kw))

  def merge(context) when is_map(context) do
    new_context = Map.merge(get(), context)
    Process.put(@key, new_context)

    new_context
  end

  @doc """
  Replace the current event context with the given map or keyword list.
  """
  @spec replace(map() | list()) :: map()
  def replace(kw) when is_list(kw), do: replace(Map.new(kw))

  def replace(context) when is_map(context) do
    Process.put(@key, context)

    context
  end

  @doc """
  Put a new key-value pair in the current event context if the key does not
  already exist. You can lazy initialize the value by passing a function that
  returns the value. The function will only be called if the key does not exist
  in the current event context.
  """
  @spec put_new(atom(), (-> any()) | any()) :: map()
  def put_new(key, f) when is_function(f, 0) do
    new_context = Map.put_new_lazy(get(), key, f)
    Process.put(@key, new_context)
    new_context
  end

  def put_new(key, value) when is_atom(key) do
    new_context = Map.put_new(get(), key, value)
    Process.put(@key, new_context)
    new_context
  end

  @doc """
  Get the current event context map
  """
  @spec get() :: map()
  def get, do: Process.get(@key, %{})

  @spec get(atom()) :: any() | nil
  def get(key) when is_atom(key) do
    Map.get(get(), key)
  end

  @doc """
  Get the current event context map from the closest parent process. Will not
  inherit if current process already has a context.
  """
  @spec inherit() :: :already_initialized | :inherited | :not_found
  def inherit do
    if Process.get(@key) == nil do
      case get_from_parents() do
        nil ->
          :not_found

        data ->
          merge(data)
          :inherited
      end
    else
      :already_initialized
    end
  end

  @doc false
  defp get_from_parents, do: ProcessTree.get(@key)
end
