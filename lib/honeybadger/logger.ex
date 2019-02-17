defmodule Honeybadger.Logger do
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

  def handle_event({:error, _gl, {Logger, _msg, _ts, metadata}}, state) do
    case Keyword.get(metadata, :crash_reason) do
      {reason, stacktrace} ->
        Honeybadger.notify(reason, extract_context(metadata), stacktrace)

      reason when is_atom(reason) and not is_nil(reason) ->
        Honeybadger.notify(reason, extract_context(metadata), [])

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

  defp extract_context(metadata) do
    metadata
    |> Keyword.drop([:ancestors, :callers, :crash_reason, :pid])
    |> Map.new()
  end
end
