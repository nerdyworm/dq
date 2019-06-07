defmodule DQTest do
  use ExUnit.Case
  Process.register(self(), __MODULE__)

  setup do
    Process.register(self(), __MODULE__)
    :ok
  end

  test "new_id" do
    assert String.starts_with?(DQ.new_id(), "DQ")
    assert DQ.new_id() != DQ.new_id()
  end

  test "collector" do
    {:ok, _pid} = DQ.Collector.start_link(max: 10, max_ms: 50, name: :test)

    Enum.each(1..25, fn i ->
      spawn(fn ->
        :ok = DQ.Collector.collect(:test, __MODULE__, {__MODULE__, [i]})
      end)
    end)

    assert_receive {:ok, 10}
    assert_receive {:ok, 10}
    assert_receive {:ok, 5}
  end

  def push(jobs) do
    Process.send(__MODULE__, {:ok, length(jobs)}, [])
    :ok
  end
end
