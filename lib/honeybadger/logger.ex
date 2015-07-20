defmodule Honeybadger.Logger do
  require Logger
  alias Honeybadger.Utils

  @ignored_keys [:pid, :function, :line, :module]

  use GenEvent

  def init(_mod), do: {:ok, []}

  def handle_call({:configure, new_keys}, _state) do
    {:ok, :ok, new_keys}
  end

  def handle_event({level, _gl, _event}, state)
  when level != :error do
    {:ok, state}
  end

  def handle_event({_level, gl, _event}, state)
  when node(gl) != node() do
    {:ok, state}
  end

  # Error messages from Ranch/Cowboy come in the form of iodata. We ignore
  # these because they should already be reported by Honeybadger.Plug.
  def handle_event({:error, _gl, {_mod, message, _ts, _pdict}}, state) 
  when is_list(message) do
    {:ok, state}
  end

  def handle_event({:error, _gl, {Logger, message, _ts, pdict}}, state) do
    try do
      stack = System.stacktrace
      exception = Utils.exception_from_message(message)
      context = Dict.drop(pdict, @ignored_keys) |> Enum.into(Map.new)
      Honeybadger.notify(exception, context, stack)
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
