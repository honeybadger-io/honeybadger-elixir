defmodule MixappTest do
  use ExUnit.Case

  test "does not crash when HONEYBADGER_API_KEY is not set" do
    assert System.get_env("HONEYBADGER_API_KEY") == nil
    # the app would crash before this assert if there was an error
    assert 1 == 1
  end
end
