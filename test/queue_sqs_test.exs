defmodule QueueSqsTest do
  # use QueueAdapterCase
  use ExUnit.Case

  defmodule Pool do
    use DQ.Pool, otp_app: :dq, after_empty_result_ms: 500, producers: 1, max_demand: 10
  end

  defmodule Queue do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Sqs,
      retry_intervals: [0],
      queue_name: "dq_test",
      dead_queue_name: "dq_test_error",
      queue_wait_time_seconds: 1
  end

  setup_all context do
    {:ok, pid} = Pool.start_link(queues: [Queue])
    on_exit(context, fn -> Process.exit(pid, :exit) end)
  end

  setup do
    Process.register(self(), __MODULE__)
    {:ok, queue: Queue, process: __MODULE__}
  end

  def run(process) when is_atom(process) do
    Process.send_after(process, :ran, 100)
    :timer.sleep(:infinity)
    :ok
  end

  @tag timeout: :infinity
  test "somthing", %{queue: queue, process: process} do
    for i <- 1..1 do
      spawn_link(fn ->
        pairs =
          Enum.map(1..50, fn _ ->
            {__MODULE__, [process]}
          end)

        assert :ok = queue.push(pairs)
      end)
    end

    # Enum.each(1..10, fn _ ->
    #   assert_receive :ran, 30_000
    # end)

    :timer.sleep(:infinity)
  end
end
