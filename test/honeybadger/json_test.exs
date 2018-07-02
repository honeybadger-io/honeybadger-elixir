defmodule Honeybadger.JSONTest do
  use Honeybadger.Case

  alias Honeybadger.{Notice, JSON}

  describe "encode" do
    test "encodes notice" do
      notice = Notice.new(%RuntimeError{message: "oops"}, %{}, [])
      assert JSON.encode(notice) == Jason.encode(notice)
    end

    defmodule Req do
      defstruct [:ip]
    end

    test "encodes notice when context has structs" do
      {:ok, json} =
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

      assert json == ""
    end
  end
end
