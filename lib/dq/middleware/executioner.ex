defmodule DQ.Middleware.Executioner do
  alias DQ.{
    Context,
    Job,
    Encoder,
  }

  def call(%Context{job: %Job{module: module, args: args}}, _next) do
    case :erlang.apply(module, :run, args) do
      :ok -> :ok
    end
  end
end


