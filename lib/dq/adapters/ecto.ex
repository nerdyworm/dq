defmodule DQ.Adapters.Ecto do
  @behaviour DQ.Adapter

  alias DQ.{
    Info,
    Job,
    Encoder,
    Adapters.Ecto.Statements
  }

  alias Ecto.Adapters.SQL

  def info(queue) do
    %Postgrex.Result{columns: columns, rows: [row]} = sql(queue, Statements.info, [])
    cols = Enum.map(columns, &(String.to_atom(&1)))
    {:ok, struct(Info, Enum.zip(cols, row))}
  end

  def push(queue, jobs) when is_list(jobs) do
    Enum.each(jobs, fn({module, args}) ->
      queue.push(module, args)
    end)
  end

  def sql(queue, statement, args) do
    repo = queue.config[:repo]
    table = queue.config |> Keyword.get(:table, :jobs) |> Atom.to_string
    statement =
      statement
      |> String.replace("$TABLE$", table)
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")

    SQL.query!(repo, statement, args)
  end

  def push(queue, module, args, opts \\ []) do
    insert(queue, module, args, opts)
    :ok
  end

  def timer(queue, module, args, opts \\ []) do
    insert(queue, module, args, opts)
  end

  defp insert(queue, module, args, opts) do
    scheduled_at = Keyword.get(opts, :scheduled_at, nil)
    scheduled_at = cast_scheduled_at(scheduled_at)

    max_runtime_seconds = Keyword.get(opts, :max_runtime_seconds, 30)
    payload = Encoder.encode({module, args})
    results = sql(queue, Statements.insert, [payload, max_runtime_seconds, scheduled_at])
    %Postgrex.Result{columns: ["id"], rows: [[job_id]]} = results
    {:ok, job_id}
  end

  defp cast_scheduled_at(scheduled_at) when is_nil(scheduled_at) do
    nil
  end

  defp cast_scheduled_at(scheduled_at) when is_binary(scheduled_at) do
    Ecto.DateTime.cast!(scheduled_at)
  end

  defp cast_scheduled_at(scheduled_at), do: scheduled_at

  def pop(queue, _) do
    res  = sql(queue, Statements.pop, [])
    jobs = decode_results(res, queue)
    {:ok, jobs}
  end

  def ack(queue, job) do
    %Postgrex.Result{num_rows: 1} = sql(queue, Statements.ack, [job.id])
    :ok
  end

  def nack(queue, job, message) do
    retries  = job.error_count
    interval = queue.config[:retry_intervals] |> Enum.at(retries)
    if interval do
      sql(queue, Statements.nack, [message, "#{interval}", job.id])
    else
      sql(queue, Statements.nack_dead, [message, job.id])
    end
    :ok
  end

  defp decode_results(%Postgrex.Result{columns: columns, rows: rows}, queue) do
    type = queue.job_struct()
    cols = Enum.map(columns, &(String.to_atom(&1)))
    Enum.map(rows, fn(row) ->
      job = struct(type, Enum.zip(cols, row))
      {module, args} = Encoder.decode(job.payload)
      %{job | module: module, args: args}
    end)
  end

  def dead(queue, limit \\ 100) do
    jobs =
      sql(queue, Statements.dead, [limit])
      |> decode_results(queue)

    {:ok, jobs}
  end

  def dead_ack(queue, %{id: id}) when is_integer(id) do
    %Postgrex.Result{num_rows: 1} = sql(queue, Statements.ack, [id])
    :ok
  end

  def dead_ack(queue, %{id: id} = job) when is_binary(id) do
    job = %{job | id: id |> String.to_integer}
    dead_ack(queue, job)
  end

  def dead_retry(queue, %{id: id}) when is_integer(id) do
    %Postgrex.Result{num_rows: 1} = sql(queue, Statements.retry, [id])
    :ok
  end

  def dead_retry(queue, %{id: id} = job) when is_binary(id) do
    job = %{job | id: id |> String.to_integer}
    dead_retry(queue, job)
  end

  def dead_purge(queue) do
    sql(queue, Statements.dead_purge, [])
    :ok
  end

  def purge(queue) do
    sql(queue, Statements.purge, [])
    :ok
  end

  def encode(job) do
    job
    |> Encoder.encode
    |> Base.encode64
  end

  def decode(job) do
    job
    |> Base.decode64!
    |> Encoder.decode
  end
end
