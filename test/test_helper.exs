Logger.remove_backend(:console)

ExUnit.start(assert_receive_timeout: 1000, refute_receive_timeout: 1000)

defmodule Honeybadger.Case do
  use ExUnit.CaseTemplate

  using(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  def with_config(opts, fun) when is_function(fun) do
    original = take_original_env(opts)

    try do
      put_all_env(opts)

      fun.()
    after
      put_all_env(original)
    end
  end

  def restart_with_config(opts) do
    :ok = Application.stop(:honeybadger)
    original = take_original_env(opts)

    put_all_env(opts)

    on_exit(fn ->
      put_all_env(original)
    end)

    :ok = Application.ensure_started(:honeybadger)
  end

  def capture_log(fun) do
    Logger.add_backend(:console, flush: true)

    on_exit(fn ->
      Logger.remove_backend(:console)
    end)

    ExUnit.CaptureIO.capture_io(:user, fn ->
      fun.()
      :timer.sleep(100)
      Logger.flush()
    end)
  end

  defp take_original_env(opts) do
    Keyword.take(Application.get_all_env(:honeybadger), Keyword.keys(opts))
  end

  defp put_all_env(opts) do
    Enum.each(opts, fn {key, val} ->
      Application.put_env(:honeybadger, key, val)
    end)
  end
end

defmodule Honeybadger.API do
  import Plug.Conn

  alias Plug.Conn
  alias Plug.Adapters.Cowboy

  def start(pid) do
    Cowboy.http(__MODULE__, [test: pid], port: 4444)
  end

  def stop do
    :timer.sleep(100)
    Cowboy.shutdown(__MODULE__.HTTP)
    :timer.sleep(100)
  end

  def init(opts) do
    Keyword.fetch!(opts, :test)
  end

  def call(%Conn{method: "POST"} = conn, test) do
    {:ok, body, conn} = read_body(conn)

    send(test, {:api_request, Poison.decode!(body)})

    send_resp(conn, 200, "{}")
  end

  def call(conn, _test) do
    send_resp(conn, 404, "Not Found")
  end
end
