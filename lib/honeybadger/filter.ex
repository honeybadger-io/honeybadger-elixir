defmodule Honeybadger.Filter do
  @moduledoc """
  This module defines macros useful in implementing a Honeybadger Notice
  filter.  Enable a filter in the config:

      config :honeybadger,
        filter: MyApp.MyFilter

   Define a module and `use` this module.  Then override any of the
   functions in your module.  E.g., if you are only interested in filtering
   the context, then you only need to override that function:

      defmodule MyApp.MyFilter do
        use Honeybadger.Filter

        # drop password fields out of the context Map
        def filter_context(context),
          do: Map.drop(context, [:password])
      end
  """
  defmacro __using__(_) do
    quote location: :keep do

      @doc """
      Top level filter function.  Should return a `%Honeybadger.Notice{}`
      struct.  This default implementation invokes the helper functions and
      returns the filtered notice.
      """
      def filter(%Honeybadger.Notice{} = notice) do
        notice
        |> Map.put(:request, filter_request(notice.request))
        |> Map.put(:error, filter_error(notice.error))
      end

      @doc """
      Filters the request object.  If you only care about filtering part of
      the request info (e.g., `params` or `context`), then override the
      more specific functions below.

      `request` is a map that looks like:

          request: %{action: :show,
            component: SomeApp.PageController,
            context: %{account_id: 1, user_id: 1},
            params: %{"query_param" => "value"},
            url: "/pages/1"}
      """
      def filter_request(request) do
        filtered_context =
          case request |> Map.get(:context) do
            nil -> nil
            context -> filter_context(context)
          end

        filtered_params =
          case request |> Map.get(:params) do
            nil -> nil
            params -> filter_params(params)
          end

        request
        |> Map.put(:context, filtered_context)
        |> Map.put(:params, filtered_params)
      end

      @doc """
      Filter the context Map.  `context` is a map of application supplied
      data. This default implementation returns the unmodified context.
      """
      def filter_context(context), do: context

      @doc """
      Filter query parameters (e.g., for a web app that uses the
      `Honeybadger.Plug`).  `params` is a map of string to string, e.g.,

           %{"user_name" => "fred", "password" => "12345"}

      This default implementation returns the unmodified params.
      """
      def filter_params(params), do: params

      @doc """
      Filter the error struct.  This default implementation just calls
      `filter_error_message` and returns the error with the filtered
      message.  An error struct looks like:

          error: %{backtrace: [%{context: "all",
                               file: "lib/elixir/lib/kernel.ex",
                               method: "+",
                               number: 321}],
          class: "RuntimeError",
          message: "Oops",
          tags: [:some_tag]}
      """
      def filter_error(%{message: message} = error) do
        error
        |> Map.put(:message, filter_error_message(message))
      end

      @doc """
      Filter the error message string. `message` is a string.  Should
      return a string.  This default implementation returns the message
      unmodified.
      """
      def filter_error_message(message), do: message

      defoverridable [filter: 1, filter_request: 1,
                      filter_context: 1, filter_params: 1,
                      filter_error: 1, filter_error_message: 1]
    end
  end
end
