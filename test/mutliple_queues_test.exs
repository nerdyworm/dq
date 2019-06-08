defmodule DQ.MultipleQueuesTest do
  use ExUnit.Case

  defmodule Pool do
    use DQ.Pool, otp_app: :dq, after_empty_result_ms: 500
  end

  defmodule A do
    use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Ecto, repo: DQ.Repo, polling_ms: 100
  end

  defmodule B do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Sqs,
      retry_intervals: [0],
      queue_name: "dq_test",
      dead_queue_name: "dq_test_error",
      queue_wait_time_seconds: 0
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

  test "work puller" do
    {:ok, _pid} = Pool.start_link(queues: [A, B])
    assert :ok = A.push(__MODULE__, ["A"])
    assert :ok = B.push(__MODULE__, ["B"])
    assert_receive :A, 10_000
    assert_receive :B, 10_000
  end
end
