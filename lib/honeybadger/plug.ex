if Code.ensure_loaded?(Plug) do
  defmodule Honeybadger.Plug do
    @moduledoc """
    The `Honeybadger.Plug` adds automatic error handling to a plug pipeline.

    Within a `Plug.Router` or `Phoenix.Router` use the module and crashes will
    be reported to Honeybadger. It's best to `use Honeybadger.Plug` **after
    the Router plugs** so that exceptions due to non-matching routes are not
    reported to Honeybadger.

    ### Example

        defmodule MyPhoenixApp.Router do
          use Crywolf.Web, :router
          use Honeybadger.Plug

          pipeline :browser do
            [...]
          end
        end

    ## Customizing

    Data reporting may be customized by passing an alternate `:plug_data`
    module. This is useful when working with alternate frameworks, such as
    Absinthe for GraphQL APIs.

    Any module with a `metadata/2` function that accepts a `Plug.Conn` and a
    `module` name can be used to generate metadata.

    ### Example

        defmodule MyPhoenixApp.Router do
          use Crywolf.Web, :router
          use Honeybadger.Plug, plug_data: MyAbsinthePlugData
        end
    """

    alias Honeybadger.PlugData
    alias Honeybadger.Breadcrumbs.{Breadcrumb, Collector}

    @doc false
    defmacro __using__(opts) do
      quote location: :keep do
        use Plug.ErrorHandler

        @plug_data Keyword.get(unquote(opts), :plug_data, PlugData)

        @doc """
        Called by `Plug.ErrorHandler` when an error is caught.

        By default this ignores "Not Found" errors for `Plug` or `Phoenix`
        pipelines. It may be overridden to ignore additional errors or to
        customize the data that is used for notifications.
        """
        @spec handle_errors(Plug.Conn.t(), %{kind: atom(), reason: any(), stack: any()}) :: :ok
        def handle_errors(_conn, %{reason: %FunctionClauseError{function: :do_match}}), do: :ok

        def handle_errors(conn, %{reason: reason, stack: stack}) do
          if Plug.Exception.status(reason) == 404 do
            # 404 errors are not reported
            :ok
          else
            Collector.add(Breadcrumb.from_error(reason))
            metadata = @plug_data.metadata(conn, __MODULE__)
            Honeybadger.notify(reason, metadata: metadata, stacktrace: stack)
          end
        end

        defoverridable handle_errors: 2
      end
    end
  end
end
