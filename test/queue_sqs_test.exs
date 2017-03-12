defmodule QueueSqsTest do
  use QueueAdapterCase

  defmodule Queue do
    use DQ, otp_app: :dq,
      adapter: DQ.Adapters.Sqs,
      retry_intervals: [0],
      queue_name: "dq_test",
      dead_queue_name: "dq_test_error",
      queue_wait_time_seconds: 1
  end

  setup_all context do
    {:ok, pid} = Queue.start_link
    on_exit(context, fn() -> Process.exit(pid, :exit) end)
  end

  setup do
    Process.register(self(), __MODULE__)
    {:ok, queue: Queue, process: __MODULE__}
  end
end

