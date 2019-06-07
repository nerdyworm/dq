defmodule DQ.Collector do
  use GenServer

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def collect(server, queue, job) do
    GenServer.call(server, {:collect, queue, job})
  end

  # def collect(queue, {mod, args}) do
  #   GenServer.call(__MODULE__, {:collect, queue, {mod, args}})
  # end

  # def collect(queue, {mod, args, opts}) do
  #   GenServer.call(__MODULE__, {:collect, queue, {mod, args, opts}})
  # end

  def init(opts) do
    {:ok,
     %{
       buffer: [],
       timer: nil,
       func: Keyword.get(opts, :func, :push),
       max: Keyword.get(opts, :max, 10),
       max_ms: Keyword.get(opts, :max_ms, 500)
     }}
  end

  def handle_call({:collect, queue, pair}, from, state) do
    state = %{state | buffer: [{queue, pair, from} | state.buffer]}

    if length(state.buffer) < state.max do
      {:noreply, timer(state)}
    else
      {:noreply, flush(state)}
    end
  end

  def handle_info(:expired, state) do
    {:noreply, flush(state)}
  end

  def handle_info(:flush, %{buffer: []} = state) do
    {:noreply, state}
  end

  def handle_info(:flush, state) do
    {:noreply, flush(state)}
  end

  def timer(%{timer: nil} = state) do
    timer = Process.send_after(self(), :expired, state.max_ms)
    %{state | timer: timer}
  end

  def timer(%{timer: timer} = state) do
    Process.cancel_timer(timer)

    %{state | timer: nil}
    |> timer()
  end

  def flush(state) do
    Process.cancel_timer(state.timer)

    [{queue, _, _} | _] = state.buffer

    pairs =
      Enum.map(state.buffer, fn {_, pair, _} ->
        pair
      end)

    :ok = apply(queue, state.func, [pairs])

    Enum.each(state.buffer, fn {_, _, from} ->
      GenServer.reply(from, :ok)
    end)

    %{state | buffer: []}
  end
end
