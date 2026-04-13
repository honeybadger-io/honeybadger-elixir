defmodule Honeybadger.Logger do
  alias Honeybadger.Breadcrumbs.{Collector, Breadcrumb}

  @moduledoc false

  @behaviour :gen_event

  @impl true
  def init(__MODULE__) do
    init({__MODULE__, []})
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    {:ok, %{level: opts[:level]}}
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
    unless domain_ignored?(metadata[:domain], Honeybadger.get_env(:ignored_domains)) ||
             internal_error?(metadata[:application]) do
      details = extract_details(message)
      context = extract_context(metadata)
      full_context = Map.merge(details, context)

      case Keyword.get(metadata, :crash_reason) do
        {reason, stacktrace} ->
          notify(reason, full_context, stacktrace)

        reason when is_atom(reason) and not is_nil(reason) ->
          notify(reason, full_context, [])

        _ ->
          unless get_config(:sasl_logging_only) do
            notify(%RuntimeError{message: message}, full_context, [])
          end
      end
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
    breadcrumbs = Collector.put(Collector.breadcrumbs(), Breadcrumb.from_error(reason))
    metadata_with_breadcrumbs = Map.put(metadata, :breadcrumbs, breadcrumbs)

    Honeybadger.notify(reason, metadata: metadata_with_breadcrumbs, stacktrace: stacktrace)
  end

  def domain_ignored?(domain, ignored) when is_list(domain) and is_list(ignored) do
    Enum.any?(ignored, fn ignore -> Enum.member?(domain, ignore) end)
  end

  def domain_ignored?(_domain, _ignored), do: false

  def internal_error?(:honeybadger), do: true
  def internal_error?(_), do: false

  @standard_metadata ~w(ancestors callers crash_reason file function line module pid)a

  defp extract_context(metadata) do
    metadata
    |> Keyword.drop(@standard_metadata)
    |> Map.new()
  end

  # Elixir < 1.17
  defp extract_details([["GenServer ", _pid, _res, _stack, _last, _, _, last], _, state]) do
    %{last_message: last, state: state}
  end

  # Elixir < 1.17
  defp extract_details([[":gen_event handler ", name, _, _, _, _stack, _last, last], _, state]) do
    %{name: name, last_message: last, state: state}
  end

  # Elixir >= 1.17
  defp extract_details([["GenServer ", _pid, _res, _stack, _last, _, _, _, last], _, state]) do
    %{last_message: last, state: state}
  end

  # Elixir >= 1.17
  defp extract_details([[":gen_event handler ", name, _, _, _, _stack, _, _last, last], _, state]) do
    %{name: name, last_message: last, state: state}
  end

  defp extract_details(["Process ", pid | _]) do
    %{name: pid}
  end

  defp extract_details(["Task " <> _, _, "\nFunction: " <> fun, "\n    Args: " <> args]) do
    %{function: fun, args: args}
  end

  # Elixir >= 1.19 flattens chardata to a charlist before reaching backends.
  # Convert to string and parse with regex.
  defp extract_details(message) when is_list(message) do
    case IO.chardata_to_string(message) do
      "GenServer " <> _ = str -> extract_genserver_details(str)
      ":gen_event handler " <> _ = str -> extract_gen_event_details(str)
      "Task " <> _ = str -> extract_task_details(str)
      "Process " <> _ = str -> extract_process_details(str)
      _ -> %{}
    end
  end

  defp extract_details(_message) do
    %{}
  end

  defp extract_genserver_details(str) do
    details = %{}

    details =
      case Regex.run(~r/Last message(?: \(from [^)]+\))?: (.+)\nState: /s, str) do
        [_, last] -> Map.put(details, :last_message, last)
        _ -> details
      end

    case Regex.run(~r/\nState: (.+?)(\nClient .+)?\z/s, str) do
      [_, state | _] -> Map.put(details, :state, String.trim(state))
      _ -> details
    end
  end

  defp extract_gen_event_details(str) do
    details = %{}

    details =
      case Regex.run(~r/\A:gen_event handler ([^ ]+) installed in/, str) do
        [_, name] -> Map.put(details, :name, name)
        _ -> details
      end

    details =
      case Regex.run(~r/Last message: (.+)\nState: /s, str) do
        [_, last] -> Map.put(details, :last_message, last)
        _ -> details
      end

    case Regex.run(~r/\nState: (.+)\z/s, str) do
      [_, state] -> Map.put(details, :state, String.trim(state))
      _ -> details
    end
  end

  defp extract_task_details(str) do
    details = %{}

    details =
      case Regex.run(~r/\nFunction: (.+)\n    Args: /s, str) do
        [_, fun] -> Map.put(details, :function, String.trim(fun))
        _ -> details
      end

    case Regex.run(~r/\n    Args: (.+)\z/s, str) do
      [_, args] -> Map.put(details, :args, String.trim(args))
      _ -> details
    end
  end

  defp extract_process_details(str) do
    case Regex.run(~r/\AProcess (.+?) terminating/s, str) do
      [_, name] -> %{name: name}
      _ -> %{}
    end
  end

  defp get_config(key) do
    Application.get_env(:honeybadger, key)
  end
end
