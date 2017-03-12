use Mix.Config

config :dq, ecto_repos: [DQ.Repo]

config :dq, DQ.Repo, [
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "que_test",
  hostname: "localhost",
  pool_size: 10
]
