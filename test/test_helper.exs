Logger.remove_backend :console
Code.load_file("test/support/error_server.exs")
ExUnit.start()
