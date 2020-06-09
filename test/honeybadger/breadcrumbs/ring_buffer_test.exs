defmodule Honeybadger.Breadcrumbs.RingBufferTest do
  use ExUnit.Case, async: true

  alias Honeybadger.Breadcrumbs.RingBuffer

  test "adds items" do
    buffer = RingBuffer.new(2) |> RingBuffer.add(:item) |> RingBuffer.to_list()
    assert buffer == [:item]
  end

  test "shifts when limit is hit" do
    buffer =
      RingBuffer.new(2)
      |> RingBuffer.add(:a)
      |> RingBuffer.add(:b)
      |> RingBuffer.add(:c)
      |> RingBuffer.to_list()

    assert buffer == [:b, :c]
  end

  test "implements Jason.Encoder" do
    json =
      2
      |> RingBuffer.new()
      |> RingBuffer.add(123)
      |> Jason.encode!()

    assert json == "[123]"
  end
end
