defmodule QueueWithCustomEctoSchemaTest do
  use ExUnit.Case, async: true

  defmodule Pool do
    use DQ.Pool, otp_app: :dq, after_empty_result_ms: 500
  end

  defmodule YourJobSchema do
    use Ecto.Schema
    import DQ.Adapters.Ecto.Schema

    schema "jobs" do
      job()
    end
  end

  defmodule Queue do
    use DQ.Queue,
      otp_app: :dq,
      adapter: DQ.Adapters.Ecto,
      repo: DQ.Repo,
      struct: YourJobSchema,
      after_empty_result_idle_ms: 500

    def run(%YourJobSchema{}) do
      Process.send(:test, :ack, [])
      :ok
    end
  end

  setup_all context do
    {:ok, pid} = Pool.start_link(queues: [Queue])
    on_exit(context, fn -> Process.exit(pid, :exit) end)
  end

  test "custom job structs can be ran" do
    Process.register(self(), :test)
    %YourJobSchema{} = DQ.Repo.insert!(%YourJobSchema{})
    assert_receive :ack, 5000
  end
end
