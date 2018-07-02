defmodule Honeybadger.JSON do
  @moduledoc false

  @spec encode(term) :: {:ok, String.t()} | {:error, Jason.EncodeError.t()}
  def encode(notice) do
    # try to encode without going the rabbit hole
    case safe_encode(notice) do
      {:ok, output} ->
        {:ok, output}

      {:error, %Protocol.UndefinedError{}} ->
        notice
        |> to_encodeable
        |> Jason.encode()
    end
  end

  # struct
  defp to_encodeable(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> to_encodeable()
  end

  # map
  defp to_encodeable(%{} = map) do
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

  defp to_encodeable(input) when is_pid(input) or is_port(input) or is_reference(input) do
    inspect(input)
  end

  defp to_encodeable(input) do
    input
  end

  def safe_encode(input) do
    try do
      Jason.encode(input)
    rescue
      e in Protocol.UndefinedError ->
        {:error, e}
    end
  end
end
