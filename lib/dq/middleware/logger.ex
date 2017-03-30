defmodule DQ.Middleware.Logger do
  import DQ.Middleware
  import DQ.Context

  alias DQ.{Context, Job}
  require Logger

  def call(ctx, next) do
    started_at = DateTime.utc_now
    Logger.info("#{log_context(ctx)} args=#{inspect ctx.job.args}")
    results = run(ctx, next)
    Logger.info("#{log_context(ctx)} runtime=#{formatted_diff(delta(started_at))}")
    results
  end

  defp log_context(%Context{queue: queue, job: %Job{module: module} = job}) when is_nil(module) do
    if job.error_count > 0 do
      "#{queue} #{job.id} tries=#{job.error_count}"
    else
      "#{queue} #{job.id}"
    end
  end

  defp log_context(%Context{job: job}) do
    if job.error_count > 0 do
      "#{job.id} #{job.module} tries=#{job.error_count}"
    else
      "#{job.id} #{job.module}"
    end
  end

  defp delta(started_at) do
    now_usecs = DateTime.utc_now |> DateTime.to_unix(:microseconds)
    started_usecs = started_at |> DateTime.to_unix(:microseconds)
    now_usecs - started_usecs
  end

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string, "ms"]
  defp formatted_diff(diff), do: [diff |> Integer.to_string, "µs"]
end
