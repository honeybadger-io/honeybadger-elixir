defmodule Honeybadger.Breadcrumbs.RingBuffer do
  @moduledoc false

  @type t :: %__MODULE__{buffer: [any()], size: pos_integer(), ct: non_neg_integer()}

  defstruct [:size, buffer: [], ct: 0]

  defimpl Jason.Encoder do
    def encode(buffer, opts) do
      Jason.Encode.list(Honeybadger.Breadcrumbs.RingBuffer.to_list(buffer), opts)
    end
  end

  @spec new(pos_integer()) :: t()
  def new(size) do
    %__MODULE__{size: size}
  end

  @spec add(t(), any()) :: t()
  def add(ring = %{ct: ct, size: ct, buffer: [_head | rest]}, item) do
    %__MODULE__{ring | buffer: rest ++ [item]}
  end

  def add(ring = %{ct: ct, buffer: buffer}, item) do
    %__MODULE__{ring | buffer: buffer ++ [item], ct: ct + 1}
  end

  @spec to_list(t()) :: [any()]
  def to_list(%{buffer: buffer}), do: buffer
end
