defmodule DQ.Worker do
  require Logger

  use GenServer

  alias DQ.{
    Context,
    Middleware,
    TaskSupervisor,
  }

  def run(%{queue: queue} = job) do
    job
    |> Context.new()
    |> Middleware.run(queue.middleware)
  end

  def start_link(job) do
    Task.start_link(fn -> start(job) end)
  end

  defp start(%{queue: queue, max_runtime_seconds: max_runtime_seconds} = job) do
    timeout = (max_runtime_seconds || 30) * 1000

    task = Task.Supervisor.async_nolink(TaskSupervisor, __MODULE__, :run, [job])
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, :ok} ->
        :ok = queue.ack(job)

      {:exit, reason} ->
        message = Exception.format(:exit, reason, System.stacktrace)
        :ok = queue.nack(job, message)

      nil ->
        Logger.warn "Failed to get a result in #{timeout}ms"
    end
  end
end

