defmodule Honeybadger.JSONTest do
  use Honeybadger.Case

  alias Honeybadger.{Notice, JSON}

  defmodule Req do
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

    test "encodes functions" do
      {:ok, json_encoded} =
        Notice.new(
          %RuntimeError{message: "oops"},
          %{
            context: %{
              log_format: &:gen_server.format_log/1
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
              log_format: "&:gen_server.format_log/1"
            }
          },
          []
        )
        |> Jason.encode()

      assert json_encoded == jason_encoded
    end

    test "encodes atoms as strings" do
      {:ok, json_encoded} =
        Notice.new(
          %RuntimeError{message: "oops"},
          %{
            context: %{
              status: :error
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
              status: "error"
            }
          },
          []
        )
        |> Jason.encode()

      assert json_encoded == jason_encoded
    end
  end
end
