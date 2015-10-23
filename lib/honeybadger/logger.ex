defmodule Honeybadger.Logger do
  alias Honeybadger.Utils
  require Honeybadger
  require Logger

  use GenEvent

  def init(_mod, []), do: {:ok, []}

  def handle_call({:configure, new_keys}, _state) do
    {:ok, :ok, new_keys}
  end

  def handle_event({_level, gl, _event}, state)
  when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({:error_report, _gl, {_pid, _type, [message | _]}}, state) 
  when is_list(message) do
    try do
      dict = Dict.take(message, [:error_info, :dictionary])
      context = Dict.take(dict[:dictionary], [:honeybadger_context]) |> Enum.into(Map.new)
      case Dict.get(dict, :error_info) do
        {_kind, {exception, stacktrace}, _stack} ->
          Honeybadger.notify(exception, context, stacktrace)
        {_kind, exception, stacktrace} ->
          Honeybadger.notify(exception, context, stacktrace)
      end
    rescue
      ex ->
        error_type = Utils.strip_elixir_prefix(ex.__struct__)
        reason = Exception.message(ex)
        message = "Unable to notify Honeybadger! #{error_type}: #{reason}"
        Logger.warn(message)
    end

    {:ok, state}
  end

  def handle_event({_level, _gl, _event}, state) do
    {:ok, state}
  end
end
