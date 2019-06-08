defmodule QueQueueEctoTest do
  use QueueAdapterCase

  defmodule Pool do
    use DQ.Pool, otp_app: :dq, after_empty_result_ms: 500
  end

  defmodule Queue do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Ecto,
      repo: DQ.Repo
  end

  defmodule YourJobSchema do
    use Ecto.Schema
    import DQ.Adapters.Ecto.Schema

    schema "jobs" do
      job()
    end
  end

  defmodule QueueWithStruct do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Ecto,
      struct: YourJobSchema,
      repo: DQ.Repo,
      after_empty_result_idle_ms: 500

    def run(%YourJobSchema{} = job) do
      IO.inspect(job)
      :ok
    end
  end

  def run("fire!") do
    :ok
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
