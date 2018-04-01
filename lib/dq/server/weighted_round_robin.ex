defmodule DQ.Server.WeightedRoundRobin do
  use GenServer

  defmodule State do
    defstruct current_weight: 0,
              index: -1,
              queues: [],
              gcd: nil,
              max: -1
  end

  def start_link(queues, pool) do
    GenServer.start_link(__MODULE__, queues, name: name(pool))
  end

  def name(pool) when is_nil(pool), do: __MODULE__
  def name(pool), do: Module.concat(pool, Scheduler)

  def init(queues) do
    {:ok, %State{queues: queues, gcd: gcd(queues), max: max(queues)}}
  end

  def next_queue(pool) do
    GenServer.call(name(pool), :next_queue)
  end

  def peak(pool) do
    GenServer.call(name(pool), :peak)
  end

  def handle_call(:next_queue, _from, %State{} = state) do
    {:ok, next, state} = next(state)
    {:reply, {:ok, next}, state}
  end

  def handle_call(:peak, _from, %State{} = state) do
    {:ok, next, _state} = next(state)
    {:reply, {:ok, next}, state}
  end

  defp next(%State{index: index, queues: queues} = state) do
    i = rem(index + 1, length(queues))
    cw = current_weight(state)
    state = %State{state | index: i, current_weight: cw}
    next = Enum.at(queues, i)

    if next.weight() >= cw do
      {:ok, next, state}
    else
      next(state)
    end
  end

  defp current_weight(%State{current_weight: cw, index: 0, gcd: gcd, max: max}) do
    cw = cw - gcd

    if cw <= 0 do
      max
    else
      cw
    end
  end

  defp current_weight(%State{current_weight: cw}) do
    cw
  end

  defp max(queues) when is_list(queues) do
    queues
    |> Enum.map(& &1.weight())
    |> Enum.max()
  end

  defp gcd(queues) when is_list(queues) do
    Enum.reduce(queues, 0, fn queue, acc ->
      gcd(acc, queue.weight())
    end)
  end

  defp gcd(a, 0), do: abs(a)
  defp gcd(a, b), do: gcd(b, rem(a, b))
end
