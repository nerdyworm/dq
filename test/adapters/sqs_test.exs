defmodule QueAdaptersSqsTest do
  use ExUnit.Case

  defmodule FakeQueue do
    def config do
      [repo: DQ.Repo,
       queue_name: "dq_test",
       dead_queue_name: "dq_test_error",
       queue_wait_time_seconds: 5,
       retry_intervals: [1]
     ]
    end
  end

  @adapter DQ.Adapters.Sqs

  setup_all do
    case DQ.Adapters.Sqs.purge(FakeQueue) do
      :ok ->
        :ok
      {:error, {:http_error, 403, %{code: "AWS.SimpleQueueService.PurgeQueueInProgress"}}} ->
        :ok
    end
  end

  test "can pop nothing" do
    assert {:ok, []} = @adapter.pop(FakeQueue, 10)
  end

  test "can pop one job and ack it" do
    assert :ok = @adapter.push(FakeQueue, __MODULE__, ["args"])
    assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
    assert :ok = @adapter.ack(FakeQueue, job)
    assert {:ok, []} = @adapter.pop(FakeQueue, 10)
  end

  test "can pop one job and nack it" do
    assert :ok = @adapter.push(FakeQueue, __MODULE__, ["args"])
    assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
    assert :ok = @adapter.nack(FakeQueue, job, "reasons")
    assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
    assert job.error_count == 1
    assert :ok = @adapter.ack(FakeQueue, job)
  end

  test "nacking to the limt will cause the job to be dead" do
    assert :ok = @adapter.push(FakeQueue, __MODULE__, ["args"])
    assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
    assert :ok = @adapter.nack(FakeQueue, job, "reasons")
    assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
    assert :ok = @adapter.nack(FakeQueue, job, "reasons")
    assert {:ok, []} = @adapter.pop(FakeQueue, 10)
    assert {:ok, [job]} = @adapter.dead(FakeQueue)
    assert job.status == "dead"
  end
end
