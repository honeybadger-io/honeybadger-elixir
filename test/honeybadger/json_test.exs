defmodule Honeybadger.JSONTest do
  use Honeybadger.Case

  alias Honeybadger.{Notice, JSON}

  defmodule Req do
    defstruct [:ip]
  end

  describe "encode" do
    test "encodes notice" do
      notice = Notice.new(%RuntimeError{message: "oops"}, %{}, [])
      assert JSON.encode(notice) == Jason.encode(notice)
    end

    test "encodes notice when context has structs" do
      {:ok, json_encoded} =
        Notice.new(
          %RuntimeError{message: "oops"},
          %{
            context: %{
              req: %Req{ip: "one"},
              reqs: [%Req{ip: "two"}],
              tups: {%Req{ip: "three"}, %Req{ip: "four"}}
            }
          },
          []
        )
        |> JSON.encode()

      {:ok, jason_encoded} =
        Notice.new(
          %RuntimeError{message: "oops"},
          %{
            context: %{
              req: %{ip: "one"},
              reqs: [%{ip: "two"}],
              tups: [%{ip: "three"}, %{ip: "four"}]
            }
          },
          []
        )
        |> Jason.encode()

      assert json_encoded == jason_encoded
    end
  end
end
