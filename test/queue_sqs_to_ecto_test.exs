defmodule QueueSqsToEctoTest do
  # use QueueAdapterCase
  use ExUnit.Case

  defmodule Pool do
    use DQ.Pool, otp_app: :dq, after_empty_result_ms: 500, producers: 1, max_demand: 10
  end

  defmodule Dead do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Ecto,
      repo: DQ.Repo
  end

  defmodule Queue do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Sqs,
      retry_intervals: [],
      queue_name: "dq_test",
      dead_queue: Dead,
      queue_wait_time_seconds: 1
  end

  setup_all context do
    {:ok, pid} = Pool.start_link(queues: [Queue], deads: [Dead])
    on_exit(context, fn -> Process.exit(pid, :exit) end)
  end

  setup do
    Process.register(self(), __MODULE__)
    {:ok, queue: Queue, process: __MODULE__}
  end

  def run(process, i) when is_atom(process) do
    IO.puts("running: #{i}")
    throw("Exception")
    # :timer.sleep(:infinity)
    # Process.send_after(process, :ran, 100)
    :ok
  end

  @tag timeout: :infinity
  test "somthing", %{queue: queue, process: process} do
    for i <- 1..1 do
      spawn_link(fn ->
        pairs =
          Enum.map(1..50, fn i ->
            {__MODULE__, [process, i]}
          end)

        assert :ok = queue.push(pairs)
      end)
    end

    :timer.sleep(5000)

    Enum.each(1..5, fn _ ->
      {:ok, jobs} = Dead.pop(10)

      for job <- jobs do
        Dead.ack(job)
      end
    end)
  end
end
