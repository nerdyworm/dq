defmodule DQ.Producer do
  use GenStage

  defmodule State do
    defstruct demand: 0, queue: nil
  end

  def start_link(queue) do
    GenStage.start_link(__MODULE__, queue, name: queue.producer_name)
  end

  def init(queue) do
    {:producer, %State{queue: queue}}
  end

  def handle_demand(incoming_demand, %State{demand: 0} = state) do
    state = %State{state | demand: incoming_demand}
    Process.send(self(), :pop, [])
    {:noreply, [], state}
  end

  def handle_demand(incoming_demand, %State{demand: demand} = state) do
    {:noreply, [], %State{state | demand: demand + incoming_demand}}
  end

  def handle_info(:pop, %State{queue: queue, demand: demand} = state) do
    {:ok, commands} = queue.pop(demand)

    new_messages_received = length(commands)
    new_demand = demand - new_messages_received

    cond do
      new_demand == 0 ->
        :ok

      new_messages_received == 0 ->
        Process.send_after(self(), :pop, queue.config[:polling_ms])

      true ->
        Process.send(self(), :pop, [])
    end

    {:noreply, commands, %State{state | demand: new_demand}}
  end
end


