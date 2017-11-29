defmodule DQ.Adapters.Ecto.Schema do
  @doc """
   Add the required fields to make a queue to your struct
  """
  defmacro job(opts \\ []) do
    quote bind_quoted: binding() do
      Ecto.Schema.field :payload, :binary
      Ecto.Schema.field :status, :string, default: "pending"
      Ecto.Schema.field :error_count, :integer
      Ecto.Schema.field :error_message, :string
      Ecto.Schema.field :scheduled_at, :utc_datetime
      Ecto.Schema.field :dequeued_at, :utc_datetime
      Ecto.Schema.field :deadline_at, :utc_datetime
      Ecto.Schema.field :max_runtime_seconds, :integer, default: 30
      Ecto.Schema.field :module, :binary, virtual: true
      Ecto.Schema.field :args, {:array, :binary}, virtual: true
      Ecto.Schema.field :queue, :binary, virtual: true
    end
  end
end
