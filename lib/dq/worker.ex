defmodule DQ.Worker do
  require Logger

  use GenServer

  alias DQ.{
    Job,
    Context,
    Worker,
    Middleware,
  }

  def run(queue, job) do
    Context.new(queue, job)
    |> Middleware.run(queue.middleware)
  end

  def start_link(queue, job) do
    Task.start_link(fn -> start(queue, job) end)
  end

  defp start(queue, %Job{max_runtime_seconds: max_runtime_seconds} = job) do
    timeout    = (max_runtime_seconds || 30) * 1000
    supervisor = queue.task_supervisor_name

    task = Task.Supervisor.async_nolink(supervisor, __MODULE__, :run, [queue, job])
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

