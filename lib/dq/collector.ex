defmodule DQ.Collector do
  use GenServer

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def collect(server, queue, job) do
    GenServer.call(server, {:collect, queue, job})
  end

  def async_collect(server, queue, job) do
    GenServer.cast(server, {:collect, queue, job})
  end

  def init(opts) do
    {:ok,
     %{
       buffer: [],
       timer: nil,
       func: Keyword.get(opts, :func, :push),
       max: Keyword.get(opts, :max, 10),
       deadline_ms: Keyword.get(opts, :deadline_ms, 50)
     }}
  end

  def handle_cast({:collect, queue, job}, state) do
    state = %{state | buffer: [{queue, job, :async} | state.buffer]}

    if length(state.buffer) < state.max do
      {:noreply, timer(state)}
    else
      {:noreply, flush(state)}
    end
  end

  def handle_call({:collect, queue, job}, from, state) do
    state = %{state | buffer: [{queue, job, from} | state.buffer]}

    if length(state.buffer) < state.max do
      {:noreply, timer(state)}
    else
      {:noreply, flush(state)}
    end
  end

  def handle_info({:ssl_closed, _}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info(:deadline, state) do
    {:noreply, flush(state)}
  end

  def timer(%{timer: nil} = state) do
    timer = Process.send_after(self(), :deadline, state.deadline_ms)
    %{state | timer: timer}
  end

  def timer(state) do
    state
  end

  def flush(%{buffer: []} = state) do
    state
  end

  def flush(%{buffer: buffer, timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)

    pid =
      spawn_link(fn ->
        [{queue, _, _} | _] = buffer

        jobs =
          Enum.map(buffer, fn {_, job, _} ->
            job
          end)

        # TODO - retry these batches
        :ok = apply(queue, state.func, [jobs])

        Enum.each(buffer, fn
          {_, _, :async} ->
            :ok

          {_, _, from} ->
            GenServer.reply(from, :ok)
        end)
      end)

    Process.monitor(pid)

    %{state | timer: nil, buffer: []}
  end
end
