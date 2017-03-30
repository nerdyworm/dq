defmodule MiddlewareTest do
  use ExUnit.Case

  alias DQ.{
    Middleware,
    Context,
  }

  defmodule First do
    import Middleware

    def call(ctx, next) do
      Process.send(self(), :called_first, [])
      run(ctx, next)
    end
  end

  defmodule Second do
    import Middleware
    import Context

    def call(ctx, next) do
      Process.send(self(), :called_second, [])
      assign(ctx, :ran, "second")
      |> run(next)
    end
  end

  test "runs through each middleware" do
    middlewares = [First, Second]
    ctx = Context.new(nil, nil)
    ctx = Middleware.run(ctx, middlewares)
    assert_receive :called_first
    assert_receive :called_second
    assert ctx.assigns[:ran] == "second"
  end

  test "runs the queue when no module is found" do
    Context.new(__MODULE__, %DQ.Job{args: ["args"]})
    |> Middleware.run([DQ.Middleware.Executioner])

    assert_receive :ran
  end

  def run("args") do
    Process.send(self(), :ran, [])
    :ok
  end
end
