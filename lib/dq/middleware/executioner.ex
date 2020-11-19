defmodule DQ.Middleware.Executioner do
  alias DQ.{
    Context,
    Job
  }

  def call(%Context{queue: queue, job: %{module: module} = job}, _next) when is_nil(module) do
    try_apply(queue, [job])
  end

  def call(%Context{job: %Job{module: module, args: args}}, _next) do
    try_apply(module, args)
  end

  defp try_apply(m, args) do
    try do
      apply(m, :run, List.wrap(args))
    rescue
      error ->
        {:error, Exception.format(:error, error, __STACKTRACE__)}
    catch
      kind, error ->
        {:error, Exception.format(kind, error, __STACKTRACE__)}
    end
  end
end
