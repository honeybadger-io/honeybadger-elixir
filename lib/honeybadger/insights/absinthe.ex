defmodule Honeybadger.Insights.Absinthe do
  @moduledoc """
  Captures telemetry events from GraphQL operations executed via Absinthe.

  ## Default Configuration

  By default, this module listens for the following Absinthe telemetry events:

      "absinthe.execute.operation.stop"
      "absinthe.execute.operation.exception"

  ## Custom Configuration

  You can customize the telemetry events to listen for by updating the insights_config:

      config :honeybadger, insights_config: %{
        absinthe: %{
          telemetry_events: [
            "absinthe.execute.operation.stop",
            "absinthe.execute.operation.exception",
            "absinthe.resolve.field.stop"
          ]
        }
      }

  Note that adding field-level events like "absinthe.resolve.field.stop" can
  significantly increase the number of telemetry events generated.
  """

  use Honeybadger.Insights.Base

  @required_dependencies [Absinthe]

  @telemetry_events [
    "absinthe.execute.operation.stop",
    "absinthe.execute.operation.exception"
  ]

  # This is not loaded by default since it can add a ton of events, but is here
  # in case it is added to the insights_config.
  def extract_metadata(%{resolution: resolution}, "absinthe.resolve.field.stop") do
    %{
      field_name: resolution.definition.name,
      parent_type: resolution.parent_type.name,
      state: resolution.state
    }
  end

  def extract_metadata(meta, _name) do
    %{
      operation_name: get_operation_name(meta),
      operation_type: get_operation_type(meta),
      selections: get_graphql_selections(meta),
      schema: get_schema(meta),
      errors: get_errors(meta)
    }
  end

  defp get_schema(%{blueprint: blueprint}) when is_map(blueprint), do: Map.get(blueprint, :schema)
  defp get_schema(_), do: nil

  defp get_errors(%{blueprint: blueprint}) when is_map(blueprint) do
    case Map.get(blueprint, :result) do
      result when is_map(result) -> Map.get(result, :errors)
      _ -> nil
    end
  end

  defp get_errors(_), do: nil

  defp get_graphql_selections(%{blueprint: blueprint}) when is_map(blueprint) do
    operation = current_operation(blueprint)

    case operation do
      nil ->
        []

      operation ->
        case Map.get(operation, :selections) do
          selections when is_list(selections) ->
            selections
            |> Enum.map(fn selection -> Map.get(selection, :name) end)
            |> Enum.uniq()

          _ ->
            []
        end
    end
  end

  defp get_graphql_selections(_), do: []

  defp get_operation_type(%{blueprint: blueprint}) when is_map(blueprint) do
    operation = current_operation(blueprint)

    case operation do
      nil -> nil
      operation -> Map.get(operation, :type)
    end
  end

  defp get_operation_type(_), do: nil

  defp get_operation_name(%{blueprint: blueprint}) when is_map(blueprint) do
    operation = current_operation(blueprint)

    case operation do
      nil -> nil
      operation -> Map.get(operation, :name)
    end
  end

  defp get_operation_name(_), do: nil

  # Replace Absinthe.Blueprint.current_operation/1
  defp current_operation(blueprint) do
    case Map.get(blueprint, :operations) do
      operations when is_list(operations) ->
        Enum.find(operations, fn op -> Map.get(op, :current) == true end)

      _ ->
        nil
    end
  end
end
