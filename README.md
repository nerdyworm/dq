# DQ - Durable Queue

A library for using durable message queues like SQS or Postgres by way
of Ecto.

It also has a testing adapter which allows you to run test synchronously.

# TODO

- process that polls for jobs that have timed out and restarts them

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `que` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:dq, "~> 0.1.0"}]
end
```

```elixir
defmodule Queue do
  use DQ.Queue, otp_app: :example
end


# start the DQ server to run a consumer
worker(DQ, []),
```

### Ecto (Postgres)

Allows you to create a queue based on a postgres table

#### Config
```elixir
config :example, Queue,
  adapter: DQ.Adapters.Ecto,
  repo: Simple.Repo,
  table: "job_table_name"
```

#### Migration

```elixir
defmodule Repo.Migrations.CreateYourJobsTable do
  use Ecto.Migration

  def change do
    create table(:job_table_name) do
      DQ.Adapters.Ecto.Migrations.job()
    end
    DQ.Adapters.Ecto.Migrations.indexes(:job_table_name)
  end
end
```

#### Schema

This is is optional, but it allows you to a jobs table on a per struct
basis.

```elixir
defmodule YourJobSchema do
  use Ecto.Schema
  import DQ.Adapters.Ecto.Schema

  schema "job_table_name" do
    job()
  end
end
```

### SQS
```elixir
config :example, Queue,
  adapter: DQ.Adapters.Sqs
  queue_name: "sqs_queue_name",
  dead_queue_name: "sqs_queue_name_error",
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/dq](https://hexdocs.pm/dq).

## Admin Interface

[http://dq-admin.s3-website-us-east-1.amazonaws.com](http://dq-admin.s3-website-us-east-1.amazonaws.com)


### API Config

Inside of a phoenix project
```elixir
pipeline :dq do
  plug :accepts, ["json"]
  plug DQ.Plug
end

scope "/dq", DQ do
  pipe_through :dq
  forward "/", Plug.Router, :index
end
```

```elixir
config :dq, :queues, [Queue]
config :dq, :token, "generate a long token here"
```
