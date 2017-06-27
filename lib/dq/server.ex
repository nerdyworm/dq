defmodule DQ.Server do
  require Logger

  import Supervisor.Spec

  alias DQ.{
    Producer,
    ConsumerSupervisor,
    TaskSupervisor,
  }

  def start_link(queues) when is_list(queues) do
    queue = __MODULE__

    children = [
      # TODO - allow the manager strategy to be configurable
      worker(DQ.Server.WeightedRoundRobin, [queues]),
      worker(Producer, [queue]),
      supervisor(ConsumerSupervisor, []),
      supervisor(Task.Supervisor, [[name: TaskSupervisor]])
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  def config do
    Application.get_env(:dq, :server)
  end

  def after_empty_result_ms do
    config()[:after_empty_result_ms]
  end

  def next_queue do
    DQ.Server.WeightedRoundRobin.next_queue
  end

  def peak do
    DQ.Server.WeightedRoundRobin.peak
  end

end
