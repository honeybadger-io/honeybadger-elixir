if Code.ensure_loaded?(Ash.Tracer) do
  defmodule Honeybadger.Insights.Ash do
    @moduledoc """
    Honeybadger Insights integration for the Ash Framework.

    This module implements the `Ash.Tracer` behaviour to capture Ash operations
    and send them as events to Honeybadger Insights for monitoring and analysis.

    ## Configuration

    Enable Honeybadger Insights in your config:

        config :honeybadger,
          insights_enabled: true,
          api_key: "your-api-key"

    Add the tracer to your Ash domain or resources:

        use Ash.Domain,
          tracers: [Honeybadger.Insights.Ash]

    Or per-resource:

        use Ash.Resource,
          domain: YourDomain,
          tracers: [Honeybadger.Insights.Ash]

    ## Custom Configuration

    You can customize which span types are traced via insights_config:

        config :honeybadger, insights_config: %{
          ash: %{
            trace_types: [:custom, :action, :query]
          }
        }

    The default trace types are `[:custom, :action]`.

    ## Event Structure

    A single event is emitted when each span completes, including duration
    and parent span linkage for reconstructing operation trees.
    """

    use Ash.Tracer

    defstruct [
      :id,
      :name,
      :type,
      :start_time,
      :parent_span_id,
      :error,
      :metadata
    ]

    @default_trace_types [:custom, :action]

    @impl Ash.Tracer
    def start_span(type, name) do
      if insights_enabled?() do
        parent_span = get_current_span()

        span = %__MODULE__{
          id: generate_span_id(),
          name: name,
          type: type,
          start_time: System.monotonic_time(:microsecond),
          parent_span_id: parent_span && parent_span.id,
          metadata: %{}
        }

        push_span(span)
      end

      :ok
    end

    @impl Ash.Tracer
    def trace_type?({:custom, type}) do
      trace_type?(type)
    end

    def trace_type?(type) do
      type in trace_types()
    end

    @impl Ash.Tracer
    def stop_span do
      case pop_span() do
        %__MODULE__{} = span ->
          duration = System.monotonic_time(:microsecond) - span.start_time

          event = %{
            span_id: span.id,
            name: span.name,
            parent_span_id: span.parent_span_id,
            duration: duration,
            metadata: span.metadata
          }

          event =
            if span.error do
              Map.put(event, :error, %{
                class: Honeybadger.Utils.module_to_string(span.error.__struct__),
                message: Exception.message(span.error)
              })
            else
              event
            end

          Honeybadger.event("ash.#{span.type}.stop", event)

        nil ->
          :ok
      end
    end

    @impl Ash.Tracer
    def get_span_context do
      %{honeybadger_span: get_current_span()}
    end

    @impl Ash.Tracer
    def set_span_context(%{honeybadger_span: span}) when not is_nil(span) do
      push_span(span)
    end

    def set_span_context(_) do
      :ok
    end

    @impl Ash.Tracer
    def set_metadata(_type, metadata) do
      case get_current_span() do
        %__MODULE__{} = span ->
          updated = %{span | metadata: Map.merge(span.metadata, metadata || %{})}
          replace_current_span(updated)

        _ ->
          :ok
      end
    end

    @impl Ash.Tracer
    def set_error(error, _opts \\ []) do
      if insights_enabled?() do
        needs_span? = is_nil(get_current_span())

        if needs_span? do
          start_span(:custom, "error")
        end

        span = get_current_span()
        replace_current_span(%{span | error: error})

        if needs_span? do
          stop_span()
        end
      end

      :ok
    end

    # Configuration

    defp insights_enabled? do
      Application.get_env(:honeybadger, :insights_enabled, false)
    end

    defp trace_types do
      insights_config = Application.get_env(:honeybadger, :insights_config, %{})
      ash_config = Map.get(insights_config, :ash, %{})
      Map.get(ash_config, :trace_types, @default_trace_types)
    end

    # Span stack management
    # The process dictionary holds a list (stack) of spans.
    # push/pop ensure nested spans don't clobber their parents.

    defp get_current_span do
      case Process.get(:ash_honeybadger_spans, []) do
        [current | _] -> current
        [] -> nil
      end
    end

    defp push_span(span) do
      stack = Process.get(:ash_honeybadger_spans, [])
      Process.put(:ash_honeybadger_spans, [span | stack])
    end

    defp pop_span do
      case Process.get(:ash_honeybadger_spans, []) do
        [current | rest] ->
          Process.put(:ash_honeybadger_spans, rest)
          current

        [] ->
          nil
      end
    end

    defp replace_current_span(span) do
      case Process.get(:ash_honeybadger_spans, []) do
        [_ | rest] -> Process.put(:ash_honeybadger_spans, [span | rest])
        [] -> Process.put(:ash_honeybadger_spans, [span])
      end
    end

    defp generate_span_id do
      Honeybadger.Utils.rand_id()
    end

    defmodule AshOban do
      @moduledoc """
      Helpers for integrating Honeybadger context with AshOban triggers.

      ## Usage with AshOban Triggers

      Use `capture_event_context/1` with the `extra_args` option in your AshOban
      trigger to automatically pass the current Honeybadger event context to the
      Oban job:

          oban do
            triggers do
              trigger :my_trigger do
                action :my_action
                extra_args(&Honeybadger.Insights.Ash.AshOban.capture_event_context/1)
              end
            end
          end

      The Honeybadger Oban integration will automatically restore this context when
      the job runs, ensuring request IDs and other context are preserved across
      async boundaries.
      """

      @doc """
      Captures the current Honeybadger event context for use with AshOban triggers.

      This function is designed to be used with the `extra_args` option in AshOban
      triggers. It returns a map containing the current Honeybadger event context,
      which will be merged into the Oban job's arguments.

      ## Parameters

      - `_record_or_changeset` - The record or changeset (ignored, as we only need
        the current process's context)

      ## Returns

      A map with the key `"hb_event_context"` containing the current event context.
      """
      def capture_event_context(_record_or_changeset) do
        %{"hb_event_context" => Honeybadger.event_context()}
      end
    end
  end
end
