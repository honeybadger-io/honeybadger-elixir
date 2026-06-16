defmodule Honeybadger.Breadcrumbs.Collector do
  @moduledoc false

  # The Collector provides an interface for accessing and affecting the current set of
  # breadcrumbs. Most operations are delegated to the supplied Buffer implementation. This is
  # mainly for internal use.

  alias Honeybadger.Breadcrumbs.{RingBuffer, Breadcrumb}
  alias Honeybadger.Utils

  @buffer_size 40
  @collector_key :hb_breadcrumbs

  @type t :: %{enabled: boolean(), trail: [Breadcrumb.t()]}

  def key, do: @collector_key

  @spec output() :: t()
  def output(), do: output(breadcrumbs())

  @spec output(RingBuffer.t()) :: t()
  def output(breadcrumbs) do
    %{
      enabled: Honeybadger.get_env(:breadcrumbs_enabled),
      trail: RingBuffer.to_list(breadcrumbs)
    }
  end

  @spec put(RingBuffer.t(), Breadcrumb.t()) :: RingBuffer.t()
  def put(breadcrumbs, breadcrumb) do
    RingBuffer.add(
      breadcrumbs,
      Map.update(breadcrumb, :metadata, %{}, &Utils.sanitize(&1, max_depth: 1))
    )
  end

  @spec add(Breadcrumb.t()) :: :ok
  def add(breadcrumb) do
    if Honeybadger.get_env(:breadcrumbs_enabled) do
      Process.put(@collector_key, put(breadcrumbs(), breadcrumb))
    end

    :ok
  end

  @spec clear() :: :ok
  def clear() do
    Process.put(@collector_key, RingBuffer.new(@buffer_size))
  end

  @spec breadcrumbs() :: RingBuffer.t()
  def breadcrumbs() do
    Process.get(@collector_key, RingBuffer.new(@buffer_size))
  end
end
