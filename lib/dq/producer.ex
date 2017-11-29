defmodule DQ.Producer do
  use GenStage

  defmodule State do
    defstruct demand: 0, manager: nil, history: %{}
  end

  def start_link(manager) do
    GenStage.start_link(__MODULE__, manager, name: __MODULE__)
  end

  def init(manager) do
    {:producer, %State{manager: manager}}
  end

  def handle_demand(incoming_demand, %State{demand: 0} = state) do
    Process.send(self(), :pop, [])
    {:noreply, [], %State{state | demand: incoming_demand}}
  end

  def handle_demand(incoming_demand, %State{demand: demand} = state) do
    {:noreply, [], %State{state | demand: demand + incoming_demand}}
  end

  def handle_info(:pop, %State{manager: manager, demand: demand, history: history} = state) do
    {:ok, queue} = manager.next_queue
    {:ok, commands} = queue.pop(demand)

    new_messages_received = length(commands)
    new_demand = demand - new_messages_received

    cond do
      new_demand == 0 ->
        :ok

      new_messages_received == 0 ->
        handle_empty_messages(queue, state)

      true ->
        Process.send(self(), :pop, [])
    end

    history = Map.put(history, queue, new_messages_received)
    {:noreply, commands, %State{state | demand: new_demand, history: history}}
  end

  # When we have no messages for a queue see if we should back off a bit.
  # If the next queue is the same queue, then backoff
  # If the next queue was empty last time, then backoff
  # Otherwise just try to pop messages from the next queue
  defp handle_empty_messages(current_queue, %State{manager: manager, history: history}) do
    {:ok, next} = manager.peak()

    cond do
      next == current_queue || Map.get(history, next) == 0 ->
        Process.send_after(self(), :pop, manager.after_empty_result_ms())

      true ->
        Process.send(self(), :pop, [])
    end
  end
end
