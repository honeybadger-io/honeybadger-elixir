defmodule HoneybadgerTestingException do
  defexception message: """
               Testing honeybadger via `mix honeybadger.test`. If you can see this, it works.
               """
end

defmodule Mix.Tasks.Honeybadger.Test do
  use Mix.Task

  @shortdoc "Verify your hex package installation by sending a test exception to the honeybadger service"

  def run(_) do
    with :ok <- assert_env() do
      send_notice()
    end
  end

  defp send_notice do
    # mute excluded envs
    Application.put_env(:honeybadger, :exclude_envs, [])

    {:ok, _started} = Application.ensure_all_started(:honeybadger)

    # send the notification
    Honeybadger.notify(%HoneybadgerTestingException{})

    # this will block the mix task from stopping before
    # the genserver sends the notification to honeybadger
    Honeybadger.Client |> Process.whereis() |> GenServer.stop()

    # if there is no error till this point, we should assume that our notice succeeded

    Mix.shell().info("""
    Raising 'HoneybadgerTestingException' to simulate application failure.
    ⚡ --- Honeybadger is installed! -----------------------------------------------

    Good news: You're one deploy away from seeing all of your exceptions in
    Honeybadger. For now, we've generated a test exception for you.

    If you ever need help:

    - Check out our documentation: https://hexdocs.pm/honeybadger
    - Email the founders: support@honeybadger.io

    Most people don't realize that Honeybadger is a small, bootstrapped company. We
    really couldn't do this without you. Thank you for allowing us to do what we
    love: making developers awesome.

    Happy 'badgering!

    Sincerely,
    Ben, Josh and Starr
    https://www.honeybadger.io/about/

    ⚡ --- End --------------------------------------------------------------------
    """)
  end

  defp assert_env do
    try do
      # to be able to read the env
      Mix.Task.run("app.start")
      Honeybadger.get_env(:api_key)
      :ok
    rescue
      _ ->
        Mix.shell().error("""
        Your api_key is not set
        Set it either in your config file or using the HONEYBADGER_API_KEY environment variable

        For more info visit: https://github.com/honeybadger-io/honeybadger-elixir#2-set-your-api-key-and-environment-name
        """)

        :error
    end
  end
end
