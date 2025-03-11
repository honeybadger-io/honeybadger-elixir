defmodule Honeybadger.Insights.TeslaTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  # Define a mock Tesla module just for testing
  defmodule Tesla do
  end

  describe "Tesla instrumentation" do
    test "captures Tesla request events" do
      event =
        send_and_receive(
          [:tesla, :request, :stop],
          %{duration: System.convert_time_unit(5, :millisecond, :native)},
          %{
            env: %{
              method: :get,
              url: "https://api.example.com",
              status: 200
            }
          }
        )

      assert event["event_type"] == "tesla.request.stop"
      assert event["method"] == "GET"
      assert event["host"] == "api.example.com"
      assert event["status_code"] == 200
      assert event["duration"] == 5

      refute event["url"]
    end

    test "captures Tesla request exceptions" do
      event =
        send_and_receive(
          [:tesla, :request, :exception],
          %{duration: System.convert_time_unit(30, :millisecond, :native)},
          %{
            env: %{
              method: :post,
              url: "https://a.example.net/users",
              status: 500
            }
          }
        )

      # Assert the correct data was included
      assert event["event_type"] == "tesla.request.exception"
      assert event["method"] == "POST"
      assert event["host"] == "a.example.net"
      assert event["status_code"] == 500
      assert event["duration"] == 30
    end

    test "captures full url" do
      with_config([insights_config: %{tesla: %{full_url: true}}], fn ->
        event =
          send_and_receive(
            [:tesla, :request, :stop],
            %{duration: System.convert_time_unit(5, :millisecond, :native)},
            %{
              env: %{
                method: :get,
                url: "https://api.example.com",
                status: 200
              }
            }
          )

        assert event["event_type"] == "tesla.request.stop"
        assert event["method"] == "GET"
        assert event["url"] == "https://api.example.com"
        assert event["status_code"] == 200
        assert event["duration"] == 5
      end)
    end
  end
end
