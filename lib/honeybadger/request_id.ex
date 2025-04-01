defmodule Honeybadger.RequestId do
  @moduledoc false

  @key __MODULE__

  alias Honeybadger.Utils

  @doc """
  Put a request ID into the current process.
  """
  @spec put(String.t()) :: String.t() | nil
  def put(id), do: Process.put(@key, id)

  @doc """
  Get the current request ID from the current process.
  """
  @spec get() :: String.t() | nil
  def get, do: Process.get(@key)

  @doc """
  Store the request ID from any parent process or initialize a new one. This
  will only work if the calling process is still alive. It is most reliable to
  pass the request ID explicitly whenever possible.
  """
  @spec inherit_or_initialize((-> String.t())) :: :already_set | :initialized | :inherited
  def inherit_or_initialize(default_fn \\ fn -> Utils.rand_id() end) do
    if get() do
      :already_set
    else
      case get_from_parents() do
        nil ->
          put(default_fn.())
          :initialized

        id ->
          put(id)
          :inherited
      end
    end
  end

  @doc false
  defp get_from_parents, do: ProcessTree.get(@key)
end
