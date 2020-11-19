defmodule DQ.Server.Ticker do
  use GenServer

  defmodule State do
    defstruct queues: []
  end

  def start_link(queues, pool) do
    GenServer.start_link(__MODULE__, queues, name: name(pool))
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 5000)
  end

  def name(pool) when is_nil(pool), do: __MODULE__
  def name(pool), do: Module.concat(pool, Ticker)

  def init(nil) do
    {:ok, %State{queues: []}}
  end

  def init([]) do
    {:ok, %State{queues: []}}
  end

  def init(queues) do
    schedule_tick()
    {:ok, %State{queues: queues}}
  end

  def handle_info(:tick, %State{} = state) do
    Enum.each(state.queues, & &1.tick())
    schedule_tick()
    {:noreply, state}
  end
end
