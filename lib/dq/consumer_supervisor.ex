defmodule DQ.ConsumerSupervisor do
  use ConsumerSupervisor

  alias DQ.{
    Worker
  }

  def name(pool) when is_nil(pool), do: __MODULE__
  def name(pool), do: Module.concat(pool, ConsumerSupervisor)

  def start_link(pool, producers) do
    ConsumerSupervisor.start_link(__MODULE__, [pool, producers], name: name(pool))
  end

  def init([pool, producers]) do
    children = [
      worker(Worker, [pool], restart: :temporary)
    ]

    config = pool.config()
    min_demand = Keyword.get(config, :min_demand, 1)
    max_demand = Keyword.get(config, :max_demand, 2)

    producers =
      for idx <- 1..producers do
        {DQ.Producer.name(pool, idx), min_demand: min_demand, max_demand: max_demand}
      end

    {:ok, children, strategy: :one_for_one, subscribe_to: producers}
  end
end
