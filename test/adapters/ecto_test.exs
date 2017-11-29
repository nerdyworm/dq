defmodule QueAdaptersEctoTest do
  use ExUnit.Case

  defmodule FakeQueue do
    def config do
      [repo: DQ.Repo, retry_intervals: [0]]
    end

    def job_struct do
      DQ.Job
    end
  end

  setup do
    :ok = DQ.Adapters.Ecto.purge(FakeQueue)
  end

  test "can pop nothing" do
    assert {:ok, []} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
  end

  test "can pop one job and ack it" do
    assert :ok = DQ.Adapters.Ecto.push(FakeQueue, __MODULE__, ["args"])
    assert {:ok, [job]} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
    assert :ok = DQ.Adapters.Ecto.ack(FakeQueue, job)
    assert {:ok, []} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
  end

  test "can pop one job and nack it" do
    assert :ok = DQ.Adapters.Ecto.push(FakeQueue, __MODULE__, ["args"])
    assert {:ok, [job]} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
    assert :ok = DQ.Adapters.Ecto.nack(FakeQueue, job, "reasons")
    assert {:ok, [job]} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
    assert job.error_count == 1
    assert job.error_message == "reasons"
  end

  test "nacking to the limt will cause the job to be dead" do
    assert :ok = DQ.Adapters.Ecto.push(FakeQueue, __MODULE__, ["args"])
    assert {:ok, [job]} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
    assert :ok = DQ.Adapters.Ecto.nack(FakeQueue, job, "reasons")
    assert {:ok, [job]} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
    assert :ok = DQ.Adapters.Ecto.nack(FakeQueue, job, "reasons")
    assert {:ok, []} = DQ.Adapters.Ecto.pop(FakeQueue, 10)
    assert {:ok, [job]} = DQ.Adapters.Ecto.dead(FakeQueue, 10)
    assert job.status == "dead"

    assert :ok = DQ.Adapters.Ecto.dead_purge(FakeQueue)
    assert {:ok, []} = DQ.Adapters.Ecto.dead(FakeQueue, 10)
  end
end
