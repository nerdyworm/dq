defmodule QueueInlineTest do
  use QueueAdapterCase

  defmodule Pool do
    use DQ.Pool, otp_app: :dq, after_empty_result_ms: 500
  end

  defmodule Queue do
    use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Inline
  end

  setup_all context do
    {:ok, pid} = Pool.start_link(queues: [Queue])
    on_exit(context, fn -> Process.exit(pid, :exit) end)
  end

  setup do
    Process.register(self(), __MODULE__)
    {:ok, queue: Queue, process: __MODULE__}
  end
end
