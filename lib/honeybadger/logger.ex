defmodule Honeybadger.Logger do
  require Logger
  alias Honeybadger.Utils

  use GenEvent

  def init(_mod, []), do: {:ok, []}

  def handle_call({:configure, new_keys}, _state) do
    {:ok, :ok, new_keys}
  end

  def handle_event({_level, gl, _event}, state)
  when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, _event}, state)
  when level != :error_report do
    {:ok, state}
  end

  def handle_event({error, _gl, {_pid, type, [message | _]}}, state) do
    try do
      dict = Dict.take(message, [:error_info, :dictionary])
      context = Dict.take(dict[:dictionary], [:honeybadger_context]) |> Enum.into(Map.new)
      {:error, exception, stacktrace} = Dict.get(dict, :error_info)
      Honeybadger.notify(exception, context, stacktrace)
    rescue
      ex ->
        error_type = Utils.strip_elixir_prefix(ex.__struct__)
        reason = Exception.message(ex)
        message = "Unable to notify Honeybadger! #{error_type}: #{reason}"
        Logger.warn(message)
    end

    {:ok, state}
  end
end
