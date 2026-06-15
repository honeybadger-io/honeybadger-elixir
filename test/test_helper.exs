Logger.remove_backend(:console)

Application.put_all_env(
  ex_unit: [
    assert_receive_timeout: 400,
    refute_receive_timeout: 200
  ],
  honeybadger: [
    environment_name: :test,
    api_key: "abc123",
    origin: "http://localhost:4444",
    insights_enabled: true
  ]
)

{:ok, _} = Application.ensure_all_started(:req)
{:ok, _} = Application.ensure_all_started(:hackney)

ExUnit.start(assert_receive_timeout: 1000, refute_receive_timeout: 1000)

_ = ~w(live_component live_view live_socket phoenix operation)a

defmodule Honeybadger.Case do
  use ExUnit.CaseTemplate

  using(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Polls `fun` until it returns a truthy value or `timeout` ms elapse.

  Returns the truthy value, or `false` on timeout. Use this to wait for an
  asynchronous condition (e.g. GenServer state) instead of sleeping for a
  guessed duration, which keeps timing-sensitive tests deterministic under load.
  """
  def eventually(fun, timeout \\ 1_000, interval \\ 10)
      when is_function(fun, 0) and is_integer(timeout) and timeout >= 0 and
             is_integer(interval) and interval > 0 do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_eventually(fun, deadline, interval)
  end

  defp do_eventually(fun, deadline, interval) do
    cond do
      result = fun.() ->
        result

      System.monotonic_time(:millisecond) >= deadline ->
        false

      true ->
        Process.sleep(interval)
        do_eventually(fun, deadline, interval)
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

  def capture_log(fun, device \\ :user) do
    Logger.add_backend(:console, flush: true)

    on_exit(fn ->
      Logger.remove_backend(:console)
    end)

    ExUnit.CaptureIO.capture_io(device, fn ->
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
  alias Plug.Cowboy

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
    content_type = List.first(get_req_header(conn, "content-type")) || "application/json"
    send(test, {:api_request, decode_payload(body, content_type)})
    send_resp(conn, 200, "{}")
  end

  def call(conn, _test), do: send_resp(conn, 404, "Not Found")

  defp decode_payload(body, "application/x-ndjson") do
    body
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp decode_payload(body, _), do: Jason.decode!(body)
end
