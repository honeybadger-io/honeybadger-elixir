defmodule Honeybadger.Breadcrumbs.Collector do
  @moduledoc """
  The Collector provides an interface for accessing and affecting the current
  set of breadcrumbs. Most operations are delegated to the supplied Buffer
  implementation. This is mainly for internal use.
  """

  alias Honeybadger.Breadcrumbs.{RingBuffer, Breadcrumb}
  alias Honeybadger.Utils

  @buffer_impl RingBuffer
  @buffer_size 40
  @metadata_key :hb_breadcrumbs

  @type t :: %{enabled: boolean(), trail: [Breadcrumb.t()]}

  @spec output() :: t()
  def output(), do: output(breadcrumbs())

  @spec output(@buffer_impl.t()) :: t()
  def output(breadcrumbs) do
    %{
      enabled: Honeybadger.get_env(:breadcrumbs_enabled),
      trail: @buffer_impl.to_list(breadcrumbs)
    }
  end

  @spec add(@buffer_impl.t(), Breadcrumb.t()) :: @buffer_impl.t()
  def add(breadcrumbs, breadcrumb) do
    @buffer_impl.add(
      breadcrumbs,
      Map.update(breadcrumb, :metadata, %{}, &Utils.sanitize(&1, max_depth: 1))
    )
  end

  @spec add(Breadcrumb.t()) :: :ok | nil
  def add(breadcrumb) do
    if Honeybadger.get_env(:breadcrumbs_enabled) do
      Logger.metadata([{@metadata_key, add(breadcrumbs(), breadcrumb)}])
    end
  end

  @spec clear() :: :ok
  def clear() do
    Logger.metadata([{@metadata_key, @buffer_impl.new(@buffer_size)}])
  end

  def metadata_key(), do: @metadata_key

  @spec breadcrumbs() :: @buffer_impl.t()
  def breadcrumbs() do
    Logger.metadata()
    |> Keyword.get(@metadata_key, @buffer_impl.new(@buffer_size))
  end
end
