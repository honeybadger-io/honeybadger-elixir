defmodule Honeybadger.Logger do
  alias Honeybadger.Breadcrumbs.{Collector, Breadcrumb}

  @moduledoc false

  @behaviour :gen_event

  @impl true
  def init(__MODULE__) do
    init({__MODULE__, []})
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    level = Keyword.get(opts, :level)

    {:ok, %{level: level}}
  end

  @impl true
  def handle_call({:configure, _options}, state) do
    {:ok, :ok, state}
  end

  @impl true
  def handle_event({_type, gl, _msg}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({:error, _gl, {Logger, message, _ts, metadata}}, state) do
    details = extract_details(message)
    context = extract_context(metadata)

    full_context = Map.merge(details, context)

    case Keyword.get(metadata, :crash_reason) do
      {reason, stacktrace} ->
        notify(reason, full_context, stacktrace)

      reason when is_atom(reason) and not is_nil(reason) ->
        notify(reason, full_context, [])

      _ ->
        :ok
    end

    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl true
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers

  defp notify(reason, metadata, stacktrace) do
    breadcrumbs =
      Map.get(metadata, Collector.metadata_key(), Collector.breadcrumbs())
      |> Collector.put(Breadcrumb.from_error(reason))

    metadata_with_breadcrumbs =
      metadata
      |> Map.delete(Collector.metadata_key())
      |> Map.put(:breadcrumbs, breadcrumbs)

    Honeybadger.notify(reason, metadata: metadata_with_breadcrumbs, stacktrace: stacktrace)
  end

  @standard_metadata ~w(ancestors callers crash_reason file function line module pid)a

  defp extract_context(metadata) do
    metadata
    |> Keyword.drop(@standard_metadata)
    |> Map.new()
  end

  defp extract_details([["GenServer ", _pid, _res, _stack, _last, _, _, last], _, state]) do
    %{last_message: last, state: state}
  end

  defp extract_details([[":gen_event handler ", name, _, _, _, _stack, _last, last], _, state]) do
    %{name: name, last_message: last, state: state}
  end

  defp extract_details(["Process ", pid | _]) do
    %{name: pid}
  end

  defp extract_details(["Task " <> _, _, "\nFunction: " <> fun, "\n    Args: " <> args]) do
    %{function: fun, args: args}
  end

  defp extract_details(_message) do
    %{}
  end
end
