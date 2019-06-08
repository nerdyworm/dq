defmodule MiddlewareTest do
  use ExUnit.Case

  alias DQ.{
    Job,
    Middleware,
    Context
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

      ctx
      |> assign(:ran, "second")
      |> run(next)
    end
  end

  test "runs through each middleware" do
    middlewares = [First, Second]
    ctx = Context.new(%Job{})
    ctx = Middleware.run(ctx, middlewares)
    assert_receive :called_first
    assert_receive :called_second
    assert ctx.assigns[:ran] == "second"
  end

  test "runs the queue when no module is found" do
    %DQ.Job{args: ["args"], queue: __MODULE__}
    |> Context.new()
    |> Middleware.run([DQ.Middleware.Executioner])

    assert_receive :ran
  end

  test "handles exceptions and nacks" do
    %DQ.Job{args: [:fail], queue: __MODULE__}
    |> Context.new()
    |> Middleware.run([DQ.Middleware.Executioner])

    assert_receive :ran
  end

  def run(%{args: [:fail]}) do
    Process.send(self(), :ran, [])
    raise "Error, should be caught"
  end

  def run(_job) do
    Process.send(self(), :ran, [])
    :ok
  end
end
