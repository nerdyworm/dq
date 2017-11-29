defmodule DQ.Middleware.Executioner do
  alias DQ.{
    Context,
    Job,
  }

  def call(%Context{queue: queue, job: %{module: module} = job}, _next) when is_nil(module)  do
    case :erlang.apply(queue, :run, [job]) do
      :ok -> :ok
    end
  end

  def call(%Context{job: %Job{module: module, args: args}}, _next) do
    case :erlang.apply(module, :run, args) do
      :ok -> :ok
    end
  end
end


