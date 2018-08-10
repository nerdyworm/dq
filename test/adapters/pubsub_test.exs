defmodule QueAdaptersSqsTest do
  use ExUnit.Case

  defmodule FakeQueue do
    def config do
      [
        repo: DQ.Repo,
        queue_name: "dq_test",
        dead_queue_name: "dq_test_error",
        queue_wait_time_seconds: 5,
        retry_intervals: [1],
        subscription_name: "dq-test",
        project_id: "random-testing-111111",
        topic_id: "dq-test"
      ]
    end
  end

  @adapter DQ.Adapters.Pubsub

  # test "can pop one job and ack it" do
  #   assert :ok = @adapter.push(FakeQueue, __MODULE__, ["args"])
  #   assert {:ok, jobs} = @adapter.pop(FakeQueue, 10)
  #   assert length(jobs) > 0

  #   Enum.each(jobs, fn job ->
  #     assert :ok = @adapter.ack(FakeQueue, job)
  #   end)
  # end

  @tag timeout: 1000 * 60 * 5
  test "can pop one job and nack it" do
    assert :ok = @adapter.push(FakeQueue, __MODULE__, ["args"])

    Enum.each(1..10, fn _ ->
      assert {:ok, jobs} = @adapter.pop(FakeQueue, 10)

      Enum.each(jobs, fn job ->
        assert :ok = @adapter.nack(FakeQueue, job, "reasons")
      end)
    end)

    # assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
    # assert job.error_count == 1
    # assert :ok = @adapter.ack(FakeQueue, job)
  end

  # test "nacking to the limt will cause the job to be dead" do
  #   assert :ok = @adapter.push(FakeQueue, __MODULE__, ["args"])
  #   assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
  #   assert :ok = @adapter.nack(FakeQueue, job, "reasons")
  #   assert {:ok, [job]} = @adapter.pop(FakeQueue, 10)
  #   assert :ok = @adapter.nack(FakeQueue, job, "reasons")
  #   assert {:ok, []} = @adapter.pop(FakeQueue, 10)
  #   assert {:ok, [job]} = @adapter.dead(FakeQueue)
  #   assert job.status == "dead"
  # end
end
