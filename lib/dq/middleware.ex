defmodule DQ.Middleware do
  def run(ctx, []), do: ctx
  def run(ctx, [middleware|rest]) do
    apply(middleware, :call, [ctx, rest])
  end
end
