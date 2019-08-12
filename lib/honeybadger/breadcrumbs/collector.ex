defmodule Honeybadger.Breadcrumbs.Collector do
  alias Honeybadger.Breadcrumbs.{RingBuffer, Breadcrumb}

  @buffer_impl RingBuffer
  @buffer_size 40

  @type t :: %{enabled: boolean(), trail: [Breadcrumb.t()]}

  @spec output() :: t()
  def output() do
    %{
      enabled: Honeybadger.get_env(:breadcrumbs_enabled),
      trail: @buffer_impl.to_list(breadcrumbs())
    }
  end

  @spec add(Breadcrumb.t()) :: :ok | nil
  def add(breadcrumb) do
    if Honeybadger.get_env(:breadcrumbs_enabled) do
      Process.put(
        :hb_breadcrumbs,
        @buffer_impl.add(breadcrumbs(), breadcrumb)
      ) && :ok
    end
  end

  def clear() do
    Process.put(:hb_breadcrumbs, @buffer_impl.new(@buffer_size))
  end

  defp breadcrumbs() do
    Process.get(:hb_breadcrumbs, @buffer_impl.new(@buffer_size))
  end
end
