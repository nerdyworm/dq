defmodule DQ.Adapters.Ecto.Job do
  use Ecto.Schema
  import Ecto.Schema
  import Ecto.Query
  import DQ.Adapters.Ecto.Schema

  schema "jobs" do
    job()
  end
end
