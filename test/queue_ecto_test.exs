defmodule QueQueueEctoTest do
  use QueueAdapterCase

  defmodule Queue do
    use DQ.Queue, otp_app: :dq,
      adapter: DQ.Adapters.Ecto,
      repo: DQ.Repo,
      after_empty_result_idle_ms: 500
  end

  def run("fire!") do
    :ok
  end

  setup_all context do
    {:ok, pid} = DQ.Server.start_link([Queue])
    on_exit(context, fn() -> Process.exit(pid, :exit) end)
  end

  setup do
    Process.register(self(), __MODULE__)
    {:ok, queue: Queue, process: __MODULE__}
  end
end

