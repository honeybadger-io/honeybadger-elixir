defmodule Honeybadger.JSON do
  @moduledoc false

  @spec encode(term) ::
          {:ok, String.t()}
          | {:error, Jason.EncodeError.t()}
          | {:error, Exception.t()}
  def encode(term) do
    case safe_encode(term) do
      {:ok, output} ->
        {:ok, output}

      {:error, _error} ->
        term
        |> to_encodeable()
        |> Jason.encode()
    end
  end

  # Keep from converting DateTime to a map
  defp to_encodeable(%DateTime{} = datetime), do: datetime

  # struct
  defp to_encodeable(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> to_encodeable()
  end

  # map
  defp to_encodeable(map) when is_map(map) do
    for {key, val} <- map, into: %{} do
      {key, to_encodeable(val)}
    end
  end

  # list
  defp to_encodeable(list) when is_list(list) do
    for element <- list, do: to_encodeable(element)
  end

  # tuple
  defp to_encodeable(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> to_encodeable
  end

  defp to_encodeable(input)
       when is_pid(input) or is_port(input) or is_reference(input) or is_function(input) do
    inspect(input)
  end

  defp to_encodeable(input) when is_binary(input) do
    case :unicode.characters_to_binary(input) do
      {:error, binary, _rest} -> binary
      {:incomplete, binary, _rest} -> binary
      _ -> input
    end
  end

  defp to_encodeable(input) do
    input
  end

  def safe_encode(input) do
    Jason.encode(input)
  rescue
    error in Protocol.UndefinedError ->
      {:error, error}
  end
end
