defmodule DQ.Adapters.Ecto.Migrations do
  @doc """
   Adds columns to a table to make it a job table
  """
  import Ecto.Migration

  def job(_opts \\ []) do
    add(:payload, :binary, null: true)
    add(:status, :string, null: false, default: "pending")
    add(:dequeued_at, :utc_datetime, null: true)
    add(:deadline_at, :utc_datetime, null: true)
    add(:scheduled_at, :utc_datetime, null: true)
    add(:max_runtime_seconds, :integer)
    add(:error_count, :integer, null: false, default: 0)
    add(:error_message, :text, null: true)
  end

  @doc """
   Adds indexs to your jobs table
  """
  def indexes(table) do
    create(index(table, [:deadline_at]))
    create(index(table, [:scheduled_at]))
  end
end
