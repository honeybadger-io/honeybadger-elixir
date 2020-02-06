defmodule Honeybadger.JSONTest do
  use Honeybadger.Case

  alias Honeybadger.{Notice, JSON}

  defmodule Request do
    defstruct [:ip]
  end

  describe "encode/1" do
    test "encodes notice" do
      notice = Notice.new(%RuntimeError{message: "oops"}, %{}, [])

      assert {:ok, encoded} = JSON.encode(notice)

      assert encoded =~ ~s|"notifier"|
      assert encoded =~ ~s|"server"|
      assert encoded =~ ~s|"error"|
      assert encoded =~ ~s|"request"|
      assert encoded =~ ~s|"breadcrumbs"|
    end

    test "encodes notice when context has structs" do
      error = %RuntimeError{message: "oops"}
      struct = %Request{ip: "0.0.0.0"}
      map = Map.from_struct(struct)

      {:ok, custom_encoded} =
        error
        |> Notice.new(%{context: %{a: struct, b: [struct], c: {struct, struct}}}, [])
        |> JSON.encode()

      {:ok, jason_encoded} =
        error
        |> Notice.new(%{context: %{a: map, b: [map], c: [map, map]}}, [])
        |> Jason.encode()

      assert custom_encoded == jason_encoded
    end

    test "handles values requring inspection" do
      {:ok, ~s("&Honeybadger.JSON.encode/1")} = JSON.encode(&Honeybadger.JSON.encode/1)
      {:ok, ~s("#PID<0.250.0>")} = JSON.encode(:c.pid(0,250,0))

      ref = make_ref()
      {:ok, encoded_ref} = JSON.encode(ref)
      assert "\"#{inspect(ref)}\"" == encoded_ref

      port = Port.open({:spawn, "false"}, [:binary])
      {:ok, encoded_port} = JSON.encode(port)
      assert "\"#{inspect(port)}\"" == encoded_port
    end

    test "safely handling binaries with invalid bytes" do
      {:ok, ~s("honeybadger")} = JSON.encode(<<"honeybadger", 241>>)
      {:ok, ~s("honeybadger")} = JSON.encode(<<"honeybadger", 241, "yo">>)
    end
  end
end
