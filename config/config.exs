use Mix.Config

config :dq, :server, [
  min_demand: 1,
  max_demand: 2,
  after_empty_result_ms: 5000,
]

import_config "#{Mix.env}.exs"
