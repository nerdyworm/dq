defmodule DQPoolTest do
  use ExUnit.Case

  defmodule Pool do
    use DQ.Pool,
      otp_app: :dq,
      after_empty_result_ms: 500
  end

  defmodule Queue do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Ecto,
      repo: DQ.Repo
  end

  def run("A") do
    Process.send(__MODULE__, :A, [])
    :ok
  end

  def run("B") do
    Process.send(__MODULE__, :B, [])
    :ok
  end

  setup do
    Process.register(self(), __MODULE__)
    :ok
  end

  test "can spawn a pool" do
    {:ok, _pid} = Pool.start_link([Queue])
    assert :ok = Queue.push(__MODULE__, ["A"])
    assert :ok = Queue.push(__MODULE__, ["B"])
    assert_receive :A, 10_000
    assert_receive :B, 10_000
  end
end
