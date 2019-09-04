defmodule Honeybadger.Breadcrumbs.Breadcrumb do
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          message: String.t(),
          category: String.t(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  @enforce_keys [:message, :category, :timestamp, :metadata]
  defstruct [:message, :category, :timestamp, :metadata]

  def new(message, opts) do
    %__MODULE__{
      message: message,
      category: opts[:category] || "custom",
      timestamp: DateTime.utc_now(),
      metadata: opts[:metadata] || %{}
    }
  end

  def from_error(error) do
    error = Exception.normalize(:error, error, [])

    %{__struct__: error_mod} = error

    new(
      Honeybadger.Utils.module_to_string(error_mod),
      metadata: %{message: error_mod.message(error)},
      category: :error
    )
  end
end
