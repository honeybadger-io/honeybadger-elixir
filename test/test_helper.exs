Logger.remove_backend :console
Code.load_file("test/support/error_server.exs")
Code.load_file("test/support/fake_http.exs")

ExUnit.start()
Application.ensure_all_started(:bypass)
