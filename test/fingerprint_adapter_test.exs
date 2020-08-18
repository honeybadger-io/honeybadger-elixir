defmodule Honeybadger.FingerprintAdapterTest do
  use Honeybadger.Case

  setup do
    {:ok, _} = Honeybadger.API.start(self())

    on_exit(&Honeybadger.API.stop/0)
  end

  describe "fingerprint adapter" do
    test "sending a notice with fingerprint adapter" do
      restart_with_config(exclude_envs: [], fingerprint_adapter: Honeybadger.CustomFingerprint)

      Honeybadger.notify("Custom error")

      assert_receive {:api_request, %{"error" => error}}
      assert error["fingerprint"] == "elixir - honeybadger-elixir"
    end

    test "notifying with fingerprint overrides the fingerprint adapter" do
      restart_with_config(exclude_envs: [], fingerprint_adapter: Honeybadger.CustomFingerprint)

      Honeybadger.notify("Custom error", fingerprint: "my-fingerprint")

      assert_receive {:api_request, %{"error" => error}}
      assert error["fingerprint"] == "my-fingerprint"
    end

    test "sending a notice without fingerprint adapter" do
      restart_with_config(exclude_envs: [], fingerprint_adapter: nil)

      Honeybadger.notify("Custom error")

      assert_receive {:api_request, %{"error" => error}}
      assert error["fingerprint"] == ""
    end
  end
end

defmodule Honeybadger.CustomFingerprint do
  @behaviour Honeybadger.FingerprintAdapter

  def parse(notice) do
    "#{notice.notifier.language} - #{notice.notifier.name}"
  end
end
