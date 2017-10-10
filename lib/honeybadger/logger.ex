defmodule Honeybadger.Logger do
  alias Honeybadger.Utils

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
      error_info = message[:error_info]
      context = get_in(message, [:dictionary, :honeybadger_context])
      context = %{context: context}

      case error_info do
        {_kind, {exception, stacktrace}, _stack} when is_list(stacktrace) ->
          Honeybadger.notify(exception, context, stacktrace)
        {_kind, exception, stacktrace} ->
          Honeybadger.notify(exception, context, stacktrace)
      end
    rescue
      exception ->
        Logger.warn(fn ->
          error_type = Utils.module_to_string(exception.__struct__)
          reason = Exception.message(exception)

          "Unable to notify Honeybadger! #{error_type}: #{reason}"
        end)
    end

    {:ok, state}
  end

  def handle_event({_level, _gl, _event}, state) do
    {:ok, state}
  end
end
