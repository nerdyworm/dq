defmodule DQ.ConsumerSupervisor do
  use ConsumerSupervisor

  alias DQ.{
    Worker
  }

  def name(pool) when is_nil(pool), do: __MODULE__
  def name(pool), do: Module.concat(pool, ConsumerSupervisor)

  def start_link(pool \\ nil) do
    ConsumerSupervisor.start_link(__MODULE__, pool, name: name(pool))
  end

  def init(pool) do
    children = [
      worker(Worker, [pool], restart: :temporary)
    ]

    config = Application.get_env(:dq, :server, [])
    min_demand = Keyword.get(config, :min_demand, 1)
    max_demand = Keyword.get(config, :max_demand, 2)

    {:ok, children,
     strategy: :one_for_one,
     subscribe_to: [
       {DQ.Producer.name(pool), min_demand: min_demand, max_demand: max_demand}
     ]}
  end
end
