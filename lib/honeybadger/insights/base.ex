defmodule Honeybadger.Insights.Base do
  @moduledoc """
  Base module providing common telemetry attachment functionality.
  """

  defmacro __using__(_opts) do
    quote do
      require Logger

      # Define empty defaults for the attributes
      Module.register_attribute(__MODULE__, :required_dependencies, [])
      @required_dependencies []
      Module.register_attribute(__MODULE__, :telemetry_events, [])
      @time_keys ~w(duration total_time decode_time query_time queue_time idle_time)a

      @before_compile Honeybadger.Insights.Base

      def dependencies_available? do
        Honeybadger.Insights.Base.dependencies_available?(@required_dependencies)
      end

      def get_insights_config(key, default) do
        Honeybadger.Insights.Base.get_insights_config(key, default, __MODULE__)
      end
    end
  end

  @doc """
  Checks if all required dependencies are available.
  """
  def dependencies_available?(deps) do
    if Enum.empty?(deps), do: true, else: Enum.all?(deps, &Code.ensure_loaded?/1)
  end

  @doc """
  Retrieves a configuration value from the insights configuration.
  """
  def get_insights_config(key, default, mod) do
    config_namespace =
      mod
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()

    insights_config = Application.get_env(:honeybadger, :insights_config, %{})
    module_config = Map.get(insights_config, config_namespace, %{})
    Map.get(module_config, key, default)
  end

  defmacro __before_compile__(_env) do
    quote do
      def event_filter(map, meta, name) do
        if Application.get_env(:honeybadger, :event_filter) do
          Application.get_env(:honeybadger, :event_filter).filter(map, meta, name)
        else
          map
        end
      end

      def get_telemetry_events() do
        get_insights_config(:telemetry_events, @telemetry_events)
      end

      @doc """
      Attaches telemetry handlers if all required dependencies are available.
      """
      def attach do
        if dependencies_available?() do
          get_telemetry_events()
          |> Enum.each(&attach_event/1)

          :ok
        else
          Logger.debug(
            "[Honeybadger] Missing Insights dependencies for #{inspect(@required_dependencies)}"
          )

          {:error, :missing_dependencies}
        end
      end

      @doc """
      Attaches a telemetry handler for a specific event.
      The event can be either a string (dot-separated) or a list of atoms.
      """
      def attach_event(event) when is_binary(event) do
        event_atoms = event |> String.split(".") |> Enum.map(&String.to_atom/1)
        attach_event(event_atoms, event)
      end

      def attach_event(event) when is_list(event) do
        event_name = Honeybadger.Utils.dotify(event)
        attach_event(event, event_name)
      end

      defp attach_event(event_atoms, event_name) do
        :telemetry.attach(
          # Use the event name as the handler ID
          event_name,
          event_atoms,
          &__MODULE__.handle_telemetry/4,
          nil
        )
      end

      defp process_measurements(measurements) do
        Enum.reduce(measurements, %{}, fn
          {key, _vl}, acc when key in ~w(monotonic_time end_time_mono)a ->
            acc

          {key, val}, acc when key in @time_keys ->
            Map.put(acc, key, System.convert_time_unit(val, :native, :millisecond))

          {key, val}, acc ->
            Map.put(acc, key, val)
        end)
      end

      @doc """
      Handles telemetry events and processes the data.
      """
      def handle_telemetry(event_name, measurements, metadata, _opts) do
        name = Honeybadger.Utils.dotify(event_name)

        unless ignore?(metadata) do
          %{event_type: name}
          |> Map.merge(process_measurements(measurements))
          |> Map.merge(
            extract_metadata(metadata, name)
            |> Map.reject(fn {_, v} -> is_nil(v) end)
          )
          |> event_filter(metadata, name)
          |> process_event()
        end

        :ok
      end

      @doc """
      Determines if an event should be ignored based on its metadata.
      Child modules should override this for specific filtering logic.
      Note: this is the metadata before any transformations.
      """
      def ignore?(_metadata), do: false

      @doc """
      Extracts metadata from the telemetry event.
      Child modules should override this for specific events.
      """
      def extract_metadata(meta, _event_name), do: meta

      @doc """
      Process the event data. Child modules can override this for custom
      processing.
      """
      def process_event(event_data) when is_map(event_data), do: Honeybadger.event(event_data)
      def process_event(_event_data), do: nil

      defoverridable extract_metadata: 2, process_event: 1, get_telemetry_events: 0, ignore?: 1
    end
  end
end
