defmodule Honeybadger.Breadcrumbs.CollectorTest do
  use Honeybadger.Case, async: true

  alias Honeybadger.Breadcrumbs.{Collector, Breadcrumb}

  setup do
    Application.put_env(:honeybadger, :breadcrumbs_enabled, true)
  end

  test "stores and outputs data" do
    bc1 = Breadcrumb.new("test1", [])
    bc2 = Breadcrumb.new("test2", [])
    Collector.add(bc1)
    Collector.add(bc2)

    assert Collector.output() == %{
             enabled: true,
             trail: [bc1, bc2]
           }
  end

  test "ignores when breadcrumbs are disabled" do
    Application.put_env(:honeybadger, :breadcrumbs_enabled, false)

    Collector.add("test1")
    Collector.add("test2")

    assert Collector.output() == %{
             enabled: false,
             trail: []
           }
  end

  test "clearing data" do
    Collector.add(Breadcrumb.new("test1", []))
    Collector.clear()

    assert Collector.output()[:trail] == []
  end
end
