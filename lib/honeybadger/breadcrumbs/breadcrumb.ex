defmodule Honeybadger.Breadcrumbs.Breadcrumb do
  @moduledoc false

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          message: String.t(),
          category: String.t(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  @type opts :: [{:metadata, map()} | {:category, String.t()}]
  @enforce_keys [:message, :category, :timestamp, :metadata]

  @default_category "custom"
  @default_metadata %{}

  defstruct [:message, :category, :timestamp, :metadata]

  @spec new(String.t(), opts()) :: t()
  def new(message, opts) do
    %__MODULE__{
      message: message,
      category: opts[:category] || @default_category,
      timestamp: DateTime.utc_now(),
      metadata: opts[:metadata] || @default_metadata
    }
  end

  @spec from_error(any()) :: t()
  def from_error(error) do
    error = Exception.normalize(:error, error, [])

    %{__struct__: error_mod} = error

    new(
      Honeybadger.Utils.module_to_string(error_mod),
      metadata: %{message: error_mod.message(error)},
      category: "error"
    )
  end
end
