defmodule QueQueueEctoTest do
  use QueueAdapterCase

  defmodule Queue do
    use DQ, otp_app: :dq, adapter: DQ.Adapters.Ecto, repo: DQ.Repo, after_empty_result_idle_ms: 500
  end

  def run("fire!") do
    :ok
  end

  setup_all context do
    {:ok, pid} = Queue.start_link
    on_exit(context, fn() -> Process.exit(pid, :exit) end)
  end

  setup do
    Process.register(self(), __MODULE__)
    {:ok, queue: Queue, process: __MODULE__}
  end

  test "timer can be started and canceled", %{queue: queue} do
    assert {:ok, timer_id} = queue.timer(__MODULE__, ["fire!"], DateTime.utc_now)
    assert :ok = queue.cancel(timer_id)
  end
end

