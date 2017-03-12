defmodule DQ.ConsumerSupervisor do
  use ConsumerSupervisor

  alias DQ.{
    Worker
  }

  def start_link(queue) do
    ConsumerSupervisor.start_link(__MODULE__, queue, name: queue.supervisor_name)
  end

  def init(queue) do
    children = [
      worker(Worker, [queue], [restart: :temporary])
    ]

    config = queue.config
    min_demand = Keyword.get(config, :min_demand, 1)
    max_demand = Keyword.get(config, :max_demand, 2)

    {:ok, children, strategy: :one_for_one, subscribe_to: [
      {queue.producer_name, min_demand: min_demand, max_demand: max_demand},
    ]}
  end
end


