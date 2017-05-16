defmodule DQ.Adapters.Inline do
  @behaviour DQ.Adapter

  alias DQ.{
    Info,
    Job,
    Worker,
  }

  use GenServer

  def start_link(queue) do
    GenServer.start_link(__MODULE__, queue)
  end

  def init(queue) do
    {:ok, queue}
  end

  def info(_) do
   {:ok, %Info{}}
  end

  def push(queue, jobs) when is_list(jobs) do
    Enum.each(jobs, fn({module, args}) ->
      queue.push(module, args)
    end)
  end

  def push(queue, module, args, _opts \\ []) do
    job = Job.new(module, args)
    Worker.run(queue, job)
  end

  def timer(queue, module, args, opts) do
    push(queue, module, args, opts)
  end

  def pop(_,_), do: {:ok, []}
  def ack(_,_), do: :ok
  def nack(_,_,_), do: :ok
  def dead(_,_limit \\ 0), do: {:ok, []}
  def purge(_), do: :ok
  def decode(_), do: nil
  def enecode(_), do: nil
  def dead_retry(_,_), do: :ok
  def dead_ack(_,_), do: :ok
  def dead_purge(_), do: :ok
  def encode(job), do: job
end
