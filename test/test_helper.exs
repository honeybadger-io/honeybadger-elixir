Logger.remove_backend(:console)

ExUnit.start()

defmodule Honeybadger.Case do
  use ExUnit.CaseTemplate

  using(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  def restart_with_config(opts) do
    :ok = Application.stop(:honeybadger)
    original = Keyword.take(Application.get_all_env(:honeybadger), Keyword.keys(opts))

    put_all_env(opts)

    on_exit(fn ->
      put_all_env(original)
    end)

    :ok = Application.ensure_started(:honeybadger)
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
    :timer.sleep(50)
    Cowboy.shutdown(__MODULE__.HTTP)
    :timer.sleep(50)
  end

  def init(opts) do
    Keyword.fetch!(opts, :test)
  end

  def call(%Conn{method: "POST"} = conn, test) do
    {:ok, body, conn} = read_body(conn)

    send test, {:api_request, Poison.decode!(body)}

    send_resp(conn, 200, "{}")
  end

  def call(conn, _test) do
    send_resp(conn, 404, "Not Found")
  end
end
