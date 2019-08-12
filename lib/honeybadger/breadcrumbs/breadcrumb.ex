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
end
