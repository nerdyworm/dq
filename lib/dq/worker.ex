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
      {:ok, {:error, message}} ->
        :ok = queue.nack(job, message)

      {:ok, _} ->
        :ok = pool.async_batch_ack(queue, job)

      nil ->
        :ok = log_timeout(queue, job, timeout)
    end
  end

  defp log_timeout(queue, job, timeout) do
    if job.error_count > 0 do
      "#{queue} #{job.id} TIMEOUT #{timeout}ms tries=#{job.error_count}"
    else
      "#{queue} #{job.id} TIMEOUT #{timeout}ms"
    end
    |> Logger.error()
  end
end
