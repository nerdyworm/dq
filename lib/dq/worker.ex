defmodule DQ.Worker do
  require Logger

  alias DQ.{Context, Middleware}

  def run(%{queue: queue} = job) do
    job
    |> Context.new()
    |> Middleware.run(queue.middleware)
  end

  def start_link(pool, job) do
    Task.start_link(fn -> start(pool, job) end)
  end

  defp start(pool, %{queue: queue, max_runtime_seconds: max_runtime_seconds} = job) do
    timeout = (max_runtime_seconds || 30) * 1000
    task = pool.start_task(job)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, :ok} ->
        :ok = queue.ack(job)

      {:ok, {:error, message}} ->
        :ok = queue.nack(job, message)

      # {:exit, reason} ->
      #   message = Exception.format(:exit, reason, System.stacktrace())
      #   :ok = queue.nack(job, message)

      nil ->
        Logger.warn("[dq] job timed out #{timeout}ms")
    end
  end
end
