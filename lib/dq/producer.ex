defmodule DQ.Producer do
  use GenStage

  defmodule State do
    defstruct demand: 0, pool: nil, idx: 0, history: %{}, queues: [], heartbeat: 0
  end

  def name(pool) when is_nil(pool), do: __MODULE__

  def name(pool, idx \\ 1),
    do:
      Module.concat(pool, Producer)
      |> Module.concat(String.to_atom(to_string(idx)))

  def start_link(pool, queues, idx) do
    GenStage.start_link(__MODULE__, [pool, queues, idx], name: name(pool, idx))
  end

  def init([pool, queues, idx]) do
    :telemetry.execute([:dq, :producer], %{pool: pool, queues: queues, idx: idx}, %{})

    {:producer,
     %State{pool: pool, queues: queues, idx: idx, heartbeat: :os.system_time(:milli_seconds)}}
  end

  def handle_demand(incoming_demand, %State{demand: 0} = state) do
    Process.send(self(), :pop, [])
    {:noreply, [], %State{state | demand: incoming_demand}}
  end

  def handle_demand(incoming_demand, %State{demand: demand} = state) do
    {:noreply, [], %State{state | demand: demand + incoming_demand}}
  end

  def handle_info(:heartbeat, %State{} = state) do
    :telemetry.execute(
      [:dq, :producer, :heartbeat],
      %{pool: state.pool, queues: state.queues, idx: state.idx},
      %{}
    )

    {:noreply, [], state}
  end

  def handle_info({:ssl_closed, _}, %State{} = state) do
    # https://github.com/benoitc/hackney/issues/464
    # https://bugs.erlang.org/browse/ERL-371
    {:noreply, [], state}
  end

  def handle_info(:pop, %State{pool: pool, demand: demand, history: history} = state) do
    {:ok, queue} = pool.next_queue()
    {:ok, jobs} = queue.pop(demand)

    new_messages_received = length(jobs)
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
    state = %State{state | demand: new_demand, history: history}
    state = heartbeat(state)
    {:noreply, jobs, state}
  end

  # When we have no messages for a queue see if we should back off a bit.
  # If the next queue is the same queue, then backoff
  # If the next queue was empty last time, then backoff
  # Otherwise just try to pop messages from the next queue
  defp handle_empty_messages(current_queue, %State{pool: pool, history: history}) do
    {:ok, next} = pool.peak()

    cond do
      next == current_queue || Map.get(history, next) == 0 ->
        Process.send_after(self(), :pop, pool.after_empty_result_ms())

      true ->
        Process.send(self(), :pop, [])
    end
  end

  def heartbeat(state) do
    now = :os.system_time(:milli_seconds)

    if now - 5000.0 > state.heartbeat do
      supervisor = DQ.ConsumerSupervisor.name(state.pool)
      children = ConsumerSupervisor.which_children(supervisor)

      :telemetry.execute(
        [:dq, :producer, :heartbeat],
        %{pool: state.pool, queues: state.queues, idx: state.idx, working: length(children)},
        %{}
      )

      %State{state | heartbeat: now}
    else
      state
    end
  end
end
