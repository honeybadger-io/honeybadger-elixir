defmodule Honeybadger.RingBuffer do
  defstruct [:buffer, :size, :ct]

  def new(size) do
    %__MODULE__{buffer: [], size: size, ct: 0}
  end

  def push(ring = %{ct: ct, size: ct, buffer: [_head | rest] }, item) do
    %__MODULE__{ring | buffer: rest ++ [item]}
  end

  def push(ring = %{ct: ct, buffer: buffer}, item) do
    %__MODULE__{ring | buffer: buffer ++ [item], ct: ct + 1}
  end

  def to_list(%{buffer: buffer}), do: buffer
end
