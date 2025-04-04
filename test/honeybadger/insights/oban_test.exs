defmodule Honeybadger.Insights.ObanTest do
  use Honeybadger.Case, async: false
  use Honeybadger.InsightsCase

  # Define mock module for testing
  defmodule Oban do
  end

  describe "Oban instrumentation" do
    test "extracts metadata from job stop event" do
      event =
        send_and_receive(
          [:oban, :job, :stop],
          %{duration: System.convert_time_unit(150, :microsecond, :native)},
          %{
            conf: %{prefix: "oban_jobs"},
            job: %{
              id: 123,
              args: %{"user_id" => 456, "action" => "send_welcome_email"},
              attempt: 1,
              queue: "mailer",
              worker: "MyApp.Mailers.WelcomeMailer",
              tags: ["email", "onboarding"]
            },
            state: :success
          }
        )

      assert event["event_type"] == "oban.job.stop"
      assert event["id"] == 123
      assert event["args"] == %{"user_id" => 456, "action" => "send_welcome_email"}
      assert event["attempt"] == 1
      assert event["queue"] == "mailer"
      assert event["worker"] == "MyApp.Mailers.WelcomeMailer"
      assert event["tags"] == ["email", "onboarding"]
      assert event["prefix"] == "oban_jobs"
      assert event["state"] == "success"
      assert event["duration"] == 150
    end

    test "extracts metadata from job exception event" do
      event =
        send_and_receive(
          [:oban, :job, :exception],
          %{duration: System.convert_time_unit(75, :microsecond, :native)},
          %{
            conf: %{prefix: "oban_jobs"},
            job: %{
              id: 456,
              args: %{"post_id" => 789, "action" => "process_image"},
              attempt: 2,
              queue: "media",
              worker: "MyApp.Media.ImageProcessor",
              tags: ["image", "processing"]
            },
            state: :failure
          }
        )

      assert event["event_type"] == "oban.job.exception"
      assert event["id"] == 456
      assert event["args"] == %{"post_id" => 789, "action" => "process_image"}
      assert event["attempt"] == 2
      assert event["queue"] == "media"
      assert event["worker"] == "MyApp.Media.ImageProcessor"
      assert event["tags"] == ["image", "processing"]
      assert event["prefix"] == "oban_jobs"
      assert event["state"] == "failure"
      assert event["duration"] == 75
    end
  end
end
