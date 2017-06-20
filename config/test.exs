use Mix.Config

config :logger, level: :warn

config :dq, :server, [
  after_empty_result_ms: 100,
]

config :dq, ecto_repos: [DQ.Repo]

config :dq, DQ.Repo, [
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "que_test",
  hostname: "localhost",
  pool_size: 10
]
