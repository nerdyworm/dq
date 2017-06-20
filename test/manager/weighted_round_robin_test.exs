defmodule DQ.Manger.WeightedRoundRobinTest do
  use ExUnit.Case

  defmodule A1, do: use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Ecto
  defmodule B1, do: use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Ecto

  test "returns a single queue" do
    {:ok, _pid} = DQ.Server.WeightedRoundRobin.start_link([A1])
    assert {:ok, A1} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A1} = DQ.Server.WeightedRoundRobin.next_queue
  end

  test "returns two queues evenly" do
    {:ok, _pid} = DQ.Server.WeightedRoundRobin.start_link([A1, B1])
    assert {:ok, A1} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, B1} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A1} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, B1} = DQ.Server.WeightedRoundRobin.next_queue
  end

  test "returns queues in weighted order" do
    defmodule A, do: use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Ecto, weight: 4
    defmodule B, do: use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Ecto, weight: 3
    defmodule C, do: use DQ.Queue, otp_app: :dq, adapter: DQ.Adapters.Ecto, weight: 2

    {:ok, _pid} = DQ.Server.WeightedRoundRobin.start_link([A, B, C])
    assert {:ok, A} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, B} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, B} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, C} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, B} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, C} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, A} = DQ.Server.WeightedRoundRobin.next_queue
    assert {:ok, B} = DQ.Server.WeightedRoundRobin.next_queue
  end
end

