defmodule Honeybadger.RingBufferTest do
  use ExUnit.Case, async: true

  alias Honeybadger.RingBuffer

  test "adds items" do
    buffer = RingBuffer.new(2) |> RingBuffer.push(:item) |> RingBuffer.to_list
    assert buffer == [:item]
  end

  test "shifts when limit is hit" do
    buffer = RingBuffer.new(2)
    |> RingBuffer.push(:a)
    |> RingBuffer.push(:b)
    |> RingBuffer.push(:c)
    |> RingBuffer.to_list

    assert buffer == [:b, :c]
  end
end
