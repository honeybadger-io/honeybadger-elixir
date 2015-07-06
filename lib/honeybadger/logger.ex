defmodule Honeybadger.Logger do

  @exception_format ~r/\((?<exception>.*?)\) (?<message>(.*))/

  use GenEvent

  def init(_module) do
    context_keys = Application.get_env(:honeybadger, :context, [])
    {:ok, context_keys}
  end

  def handle_call({:configure, _options}, context_keys) do
    {:ok, :ok, context_keys}
  end

  def handle_event({level, _gl, _event}, context_keys)
  when level != :error do
    {:ok, context_keys}
  end

  def handle_event({_level, gl, _event}, context_keys)
  when node(gl) != node() do
    {:ok, context_keys}
  end

  def handle_event({:error, _gl, {Logger, msg, _ts, [pid: pid] = pdict}}, context_keys) do
    exception = exception_from_message msg
    {:current_stacktrace, stacktrace} = Process.info(pid, :current_stacktrace)
    context = Dict.take(pdict, context_keys)
    plug_env = Dict.take(pdict, [:plug_env]) 
    metadata = Dict.merge(plug_env, context) |> Enum.into(Map.new)

    Honeybadger.notify exception, metadata, stacktrace
    {:ok, context_keys}
  end

  defp exception_from_message(message) do
    error = Regex.named_captures @exception_format, message
    type = error["exception"]
    |> String.split(".") 
    |> Module.safe_concat

    struct type, Dict.drop(error, ["exception"])
  end
end
