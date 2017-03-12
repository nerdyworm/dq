defmodule DQ.Adapters.Ecto.Job do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Query

  alias DQ.Encoder

  schema "jobs" do
    field :payload, :binary
    field :queue, :string, default: "default"
    field :status, :string, default: "pending"
    field :error_count, :integer
    field :error_message, :string
    field :enqueued_at, Ecto.DateTime
    field :dequeued_at, Ecto.DateTime
    field :deadline_at, Ecto.DateTime
    field :max_runtime_seconds, :integer, default: 30
  end

  def new(module, args) do
    %__MODULE__{payload: Encoder.encode({module, args})}
  end
end
