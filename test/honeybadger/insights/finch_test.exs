# Define a mock Finch module just for testing
defmodule Finch do
  defmodule Response do
    defstruct [:status]
  end
end

defmodule Honeybadger.Insights.FinchTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  describe "Finch instrumentation" do
    test "captures Finch request events" do
      event =
        send_and_receive(
          [:finch, :request, :stop],
          %{duration: System.convert_time_unit(10, :millisecond, :native)},
          %{
            name: :my_client,
            request: %{
              method: "GET",
              scheme: :https,
              host: "api.example.com",
              port: nil,
              path: "/users"
            },
            result: {:ok, %Finch.Response{status: 200}}
          }
        )

      assert event["event_type"] == "finch.request.stop"
      assert event["method"] == "GET"
      assert event["host"] == "api.example.com"
      assert event["status"] == 200
      assert event["duration"] == 10

      refute event["url"]
    end

    test "captures error responses" do
      error = RuntimeError.exception("connection refused")

      event =
        send_and_receive(
          [:finch, :request, :stop],
          %{duration: System.convert_time_unit(25, :millisecond, :native)},
          %{
            name: :my_client,
            request: %{
              method: "POST",
              scheme: :https,
              host: "api.example.com",
              port: 443,
              path: "/users"
            },
            result: {:error, error}
          }
        )

      assert event["event_type"] == "finch.request.stop"
      assert event["method"] == "POST"
      assert event["host"] == "api.example.com"
      assert event["error"] == "connection refused"
      assert event["duration"] == 25
    end

    test "captures streaming responses" do
      event =
        send_and_receive(
          [:finch, :request, :stop],
          %{duration: System.convert_time_unit(15, :millisecond, :native)},
          %{
            name: :my_client,
            request: %{
              method: "GET",
              scheme: :https,
              host: "api.example.com",
              port: 443,
              path: "/stream"
            },
            # Simulating a streaming accumulator
            result: {:ok, []}
          }
        )

      assert event["event_type"] == "finch.request.stop"
      assert event["method"] == "GET"
      assert event["host"] == "api.example.com"
      assert event["streaming"] == true
      assert event["duration"] == 15
    end

    test "captures full url when configured" do
      with_config([insights_config: %{finch: %{full_url: true}}], fn ->
        event =
          send_and_receive(
            [:finch, :request, :stop],
            %{duration: System.convert_time_unit(8, :millisecond, :native)},
            %{
              name: :my_client,
              request: %{
                method: "GET",
                scheme: :https,
                host: "api.example.com",
                port: 443,
                path: "/users"
              },
              result: {:ok, %Finch.Response{status: 200}}
            }
          )

        assert event["event_type"] == "finch.request.stop"
        assert event["method"] == "GET"
        assert event["host"] == "api.example.com"
        assert event["url"] == "https://api.example.com/users"
        assert event["status"] == 200
        assert event["duration"] == 8
      end)
    end

    test "handles non-standard ports correctly" do
      event =
        send_and_receive(
          [:finch, :request, :stop],
          %{duration: System.convert_time_unit(12, :millisecond, :native)},
          %{
            name: :my_client,
            request: %{
              method: "GET",
              scheme: :http,
              host: "localhost",
              port: 8080,
              path: "/api"
            },
            result: {:ok, %Finch.Response{status: 200}}
          }
        )

      assert event["event_type"] == "finch.request.stop"
      assert event["method"] == "GET"
      assert event["host"] == "localhost"
      assert event["status"] == 200
      assert event["duration"] == 12

      # Test with full_url config
      with_config([insights_config: %{finch: %{full_url: true}}], fn ->
        event =
          send_and_receive(
            [:finch, :request, :stop],
            %{duration: System.convert_time_unit(12, :millisecond, :native)},
            %{
              name: :my_client,
              request: %{
                method: "GET",
                scheme: :http,
                host: "localhost",
                port: 8080,
                path: "/api"
              },
              result: {:ok, %Finch.Response{status: 200}}
            }
          )

        assert event["url"] == "http://localhost:8080/api"
      end)
    end
  end
end
