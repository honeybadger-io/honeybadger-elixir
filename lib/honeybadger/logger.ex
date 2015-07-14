defmodule Honeybadger.Logger do
  require Logger

  @exception_format ~r/\((?<exception>.*?)\) (?<message>(.*))/

  use GenEvent

  def init(_module) do
    context_keys = Application.get_env(:honeybadger, :context, [])
    {:ok, context_keys}
  end

  def handle_call({:configure, new_keys}, _context_keys) do
    {:ok, :ok, new_keys}
  end

  def handle_event({level, _gl, _event}, context_keys)
  when level != :error do
    {:ok, context_keys}
  end

  def handle_event({_level, gl, _event}, context_keys)
  when node(gl) != node() do
    {:ok, context_keys}
  end

  def handle_event({:error, _gl, {Logger, message, _ts, pdict}}, context_keys) do
    try do
      exception = exception_from_message message
      context = Dict.take(pdict, context_keys)
      plug_env = Dict.take(pdict, [:plug_env]) 
      metadata = Dict.merge(plug_env, context) |> Enum.into(Map.new)

      Honeybadger.notify exception, metadata, System.stacktrace
    rescue
      ex ->
        error_type = Utils.strip_elixir_prefix(ex.__struct__)
        message = "Unable to notify Honeybadger! #{error_type}: #{ex.message}"
        Logger.error(message)
    end

    {:ok, context_keys}
  end

  defp exception_from_message(message)
  when is_list(message) do
    message
    |> exception_from_ranch_message
    |> exception_from_message
  end

  defp exception_from_message(message) do
    error = Regex.named_captures @exception_format, message
    type = error["exception"]
    |> String.split(".") 
    |> Module.safe_concat

    struct type, Dict.drop(error, ["exception"])
  end

  defp exception_from_ranch_message(message) do
    message
    |> IO.iodata_to_binary
    |> String.split("\n")
    |> Enum.at(4)
  end
end
