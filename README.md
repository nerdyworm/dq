# DQ - Durable Queue

A library for using durable message queues like SQS or Postgres by way
of Ecto.

It also has a testing adapter which allows you to run test synchronously.

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
  use DQ, otp_app: :example
end
```

### Postgres
```elixir
config :example, Queue,
  adapter: DQ.Adapters.Ecto
  repo: Simple.Repo
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
