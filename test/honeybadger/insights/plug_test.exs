defmodule Honeybadger.Insights.PlugTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  def mock_conn(attrs \\ %{}) do
    conn = %Plug.Conn{
      method: "GET",
      request_path: "/users/123",
      params: %{"id" => "123"},
      status: 200,
      assigns: %{},
      req_headers: %{},
      adapter: {nil, nil},
      owner: self(),
      remote_ip: {127, 0, 0, 1}
    }

    Map.merge(conn, attrs)
  end

  describe "Plug instrumentation" do
    test "extracts metadata from plug event with request_id in assigns" do
      event =
        send_and_receive(
          [:phoenix, :endpoint, :stop],
          %{duration: System.convert_time_unit(15, :millisecond, :native)},
          %{
            conn:
              mock_conn(%{
                assigns: %{request_id: "abc-xyz-123"}
              })
          }
        )

      assert event["method"] == "GET"
      assert event["request_path"] == "/users/123"
      assert event["params"] == %{"id" => "123"}
      assert event["status"] == 200
      assert event["request_id"] == "abc-xyz-123"
      assert event["duration"] == 15
    end

    test "extracts request_id from headers when not in assigns" do
      event =
        send_and_receive(
          [:phoenix, :endpoint, :stop],
          %{duration: System.convert_time_unit(10, :millisecond, :native)},
          %{
            conn:
              mock_conn(%{
                method: "POST",
                request_path: "/api/items",
                params: %{"title" => "New Item"},
                status: 201,
                assigns: %{},
                resp_headers: [{"x-request-id", "req-123-456"}]
              })
          }
        )

      assert event["method"] == "POST"
      assert event["request_path"] == "/api/items"
      assert event["params"] == %{"title" => "New Item"}
      assert event["status"] == 201
      assert event["request_id"] == "req-123-456"
      assert event["duration"] == 10
    end

    test "handles missing request_id gracefully" do
      event =
        send_and_receive(
          [:phoenix, :endpoint, :stop],
          %{duration: System.convert_time_unit(5, :millisecond, :native)},
          %{
            conn:
              mock_conn(%{
                method: "DELETE",
                request_path: "/api/items/456",
                params: %{"id" => "456"},
                status: 204
              })
          }
        )

      assert event["method"] == "DELETE"
      assert event["request_path"] == "/api/items/456"
      assert event["params"] == %{"id" => "456"}
      assert event["status"] == 204
      assert event["request_id"] == nil
      assert event["duration"] == 5
    end
  end
end
