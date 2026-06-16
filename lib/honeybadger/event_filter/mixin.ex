defmodule Honeybadger.EventFilter.Mixin do
  @moduledoc """
  Provides a mixin for implementing the Honeybadger.EventFilter behaviour.

  If you need to implement custom filtering for events, you can define your own filter module
  and register it in the config. For example, to filter based on event_type:

      defmodule MyApp.MyFilter do
        use Honeybadger.EventFilter.Mixin

        # Drop analytics events by returning nil
        def filter_event(%{event_type: "analytics"} = _event), do: nil

        # Anonymize user data in login events
        def filter_event(%{event_type: "login"} = event) do
          event
          |> update_in([:data, :user_email], fn _ -> "[REDACTED]" end)
          |> put_in([:metadata, :filtered], true)
        end

        # For telemetry events, you can customize while still applying default filtering
        def filter_telemetry_event(data, raw, event) do
          # First apply default filtering
          filtered_data = apply_default_telemetry_filtering(data)

          # Then apply custom logic
          case event do
            [:auth, :login, :start] ->
              Map.put(filtered_data, :security_filtered, true)
            _ ->
              filtered_data
          end
        end

        # Keep all other events as they are
        def filter_event(event), do: event
      end

  And set the configuration to:

      config :honeybadger,
        event_filter: MyApp.MyFilter

  Return `nil` from `filter_event/1` to prevent the event from being processed.
  If you override `filter_telemetry_event/3`, you can still apply the default
  filtering by calling `apply_default_telemetry_filtering/1`.
  """

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Honeybadger.EventFilter

      def filter_event(event), do: event

      def filter_telemetry_event(data, _raw, _event) do
        apply_default_telemetry_filtering(data)
      end

      # Default filtering implementation as a public function
      def apply_default_telemetry_filtering(data) do
        data
        |> disable(:filter_disable_url, :url)
        |> disable(:filter_disable_session, :session)
        |> disable(:filter_disable_assigns, :assigns)
        |> disable(:filter_disable_params, :params)
        |> Honeybadger.Utils.sanitize(remove_filtered: true)
      end

      defp disable(meta, config_key, map_key) do
        if Honeybadger.get_env(config_key) do
          Map.drop(meta, [map_key])
        else
          meta
        end
      end

      defoverridable Honeybadger.EventFilter
    end
  end
end
