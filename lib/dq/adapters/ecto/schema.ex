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
      Ecto.Schema.field :scheduled_at, Ecto.DateTime
      Ecto.Schema.field :dequeued_at, Ecto.DateTime
      Ecto.Schema.field :deadline_at, Ecto.DateTime
      Ecto.Schema.field :max_runtime_seconds, :integer, default: 30
    end
  end
end
