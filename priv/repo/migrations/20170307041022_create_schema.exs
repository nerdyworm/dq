defmodule DQ.Repo.Migrations.CreateSchema do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      DQ.Adapters.Ecto.Migrations.job()
    end

    DQ.Adapters.Ecto.Migrations.indexes(:jobs)
  end
end
