defmodule DQ.Repo.Migrations.CreateSchema do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :payload, :binary, null: false
      add :queue, :string, null: false, default: "default"
      add :status, :string, null: false, default: "pending"
      add :enqueued_at, :timestamp, null: true, default: "now()"
      add :dequeued_at, :timestamp, null: true
      add :deadline_at, :timestamp, null: true
      add :scheduled_at, :timestamp, null: true
      add :max_runtime_seconds, :integer
      add :error_count, :integer, null: false, default: 0
      add :error_message, :text, null: true
    end

    execute "alter table jobs alter column enqueued_at set default now() at time zone 'utc'"
    create index(:jobs, [:deadline_at])
  end
end
