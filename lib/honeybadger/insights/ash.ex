defmodule Honeybadger.Insights.Ash do
  @moduledoc """
  Captures telemetry events from Ash Framework domain actions.

  ## Default Configuration

  By default, this module listens for telemetry events from all configured
  Ash domains. It reads the `:ash_domains` configuration to identify
  domains and their telemetry events.

  ## Setup

  Configure your Ash domains in your application config:

      config :honeybadger,
        ash_domains: [MyApp.Accounts, MyApp.Posts]

  ## Custom Configuration

  You can customize this module's behavior with the following configuration options:

      config :honeybadger, insights_config: %{
        ash: %{
          # Additional custom telemetry events to listen for alongside auto-discovered ones
          telemetry_events: [
            [:ash, :my_app, :create, :stop],
            [:ash, :my_app, :read, :stop]
          ]
        }
      }

  ## Additional Telemetry Events

  By default, this module captures domain-level action events (create, read, update,
  destroy, and generic action). Ash also emits lower-level telemetry events that you
  can capture for more detailed monitoring:

  - `[:ash, :changeset, :stop]` - Changeset processing
  - `[:ash, :query, :stop]` - Query processing
  - `[:ash, :validation, :stop]` - Changeset validation
  - `[:ash, :change, :stop]` - Changeset modification
  - `[:ash, :calculation, :stop]` - Calculation computation
  - `[:ash, :before_action, :stop]` - Before action hook execution
  - `[:ash, :after_action, :stop]` - After action hook execution
  - `[:ash, :preparation, :stop]` - Query preparation

  To capture these events, add them to your `telemetry_events` configuration.
  These will be captured in addition to your configured domains:

      config :honeybadger, insights_config: %{
        ash: %{
          telemetry_events: [
            [:ash, :validation, :stop],
            [:ash, :calculation, :stop]
          ]
        }
      }

  Note: These lower-level events can generate high volumes of telemetry data. Use them
  selectively based on your monitoring needs.
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Ash]
  @telemetry_events []
  require IEx

  def get_telemetry_events do
    custom_events = get_insights_config(:telemetry_events, [])

    domain_events =
      case Application.fetch_env(:honeybadger, :ash_domains) do
        {:ok, domains} when is_list(domains) -> Enum.flat_map(domains, &get_domain_events/1)
        _ -> []
      end

    stop_events = (custom_events ++ domain_events) |> Enum.uniq()

    # Add :start events for internal context propagation
    start_events =
      Enum.reduce(stop_events, [], fn event, acc ->
        if List.last(event) == :stop do
          [Enum.drop(event, -1) ++ [:start] | acc]
        else
          acc
        end
      end)

    stop_events ++ start_events
  end

  defp get_domain_events(domain) do
    if Code.ensure_loaded?(Ash.Domain.Info) do
      short_name = apply(Ash.Domain.Info, :short_name, [domain])

      [
        [:ash, short_name, :create, :stop],
        [:ash, short_name, :read, :stop],
        [:ash, short_name, :update, :stop],
        [:ash, short_name, :destroy, :stop],
        [:ash, short_name, :action, :stop]
      ]
    else
      []
    end
  end

  def handle_telemetry(event_name, measurements, metadata, opts) do
    # Inherit Honeybadger event context on :start events to ensure
    # spawned processes (like Oban jobs) get the request_id and other context
    if List.last(event_name) == :start do
      if map_size(Honeybadger.EventContext.get()) == 0 do
        Honeybadger.inherit_event_context()
      end
    end

    # Only generate insights events if this event is in the configured list
    # By default, :start events are for internal processing only
    configured_events = get_insights_config(:telemetry_events, [])

    domain_events =
      case Application.fetch_env(:honeybadger, :ash_domains) do
        {:ok, domains} when is_list(domains) -> Enum.flat_map(domains, &get_domain_events/1)
        _ -> []
      end

    if event_name in (configured_events ++ domain_events) do
      handle_event_impl(event_name, measurements, metadata, opts)
    end

    :ok
  end

  def extract_metadata(meta, _event) do
    IEx.pry()
    # %{
    #   resource_short_name: Map.get(meta, :resource_short_name),
    #   action: Map.get(meta, :action),
    #   system_time: nil
    # }
    meta
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
