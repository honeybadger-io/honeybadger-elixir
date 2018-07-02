defmodule Honeybadger.JSON do
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
  defp to_encodeable(%_{} = input) do
    input
    |> Map.from_struct()
    |> to_encodeable()
  end

  # map
  defp to_encodeable(%{} = input) do
    for {k, v} <- input, into: %{} do
      {k, to_encodeable(v)}
    end
  end

  # list
  defp to_encodeable(input) when is_list(input) do
    for v <- input, do: to_encodeable(v)
  end

  # tuple
  defp to_encodeable(input) when is_tuple(input) do
    input
    |> Tuple.to_list()
    |> to_encodeable
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
