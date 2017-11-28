defmodule DQ.ConsumerSupervisor do
  use ConsumerSupervisor

  alias DQ.{
    Worker
  }

  def start_link do
    ConsumerSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Worker, [], [restart: :temporary])
    ]

    config = Application.get_env(:dq, :server, [])
    min_demand = Keyword.get(config, :min_demand, 1)
    max_demand = Keyword.get(config, :max_demand, 2)

    {:ok, children, strategy: :one_for_one, subscribe_to: [
      {DQ.Producer, min_demand: min_demand, max_demand: max_demand},
    ]}
  end
end


