defmodule DQ.Adapters.Sqs do
  require Logger

  alias DQ.{
    Info,
    Job,
    Encoder
  }

  alias ExAws.{
    SQS
  }

  def info(queue) do
    {:ok, info} = queue.config |> Keyword.get(:queue_name) |> info_by_queue
    {:ok, info}
    # {:ok, dead} = queue.config |> Keyword.get(:dead_queue_name) |> info_by_queue
    # {:ok, %Info{info | dead: dead.pending + dead.running}}
  end

  def purge(queue) do
    name = queue.config |> Keyword.get(:queue_name)

    case SQS.purge_queue(name) |> ExAws.request() do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> :ok
    end
  end

  def dead_purge(queue) do
    name = queue.config |> Keyword.get(:dead_queue_name)

    case SQS.purge_queue(name) |> ExAws.request() do
      {:error, reason} -> {:error, reason}
      {:ok, _} -> :ok
    end
  end

  defp info_by_queue(name) do
    {:ok, response} = SQS.get_queue_url(name) |> ExAws.request()

    case response do
      %{body: %{queue_url: queue_url}} ->
        %URI{path: "/" <> uri} = URI.parse(queue_url)
        {:ok, response} = SQS.get_queue_attributes(uri, [:all]) |> ExAws.request()
        {:ok, queue_attributes_to_info(response)}
    end
  end

  def ack(queue, jobs) when is_list(jobs) do
    name = queue.config |> Keyword.get(:queue_name)

    jobs =
      Enum.map(jobs, fn job ->
        [receipt_handle: job.message.receipt_handle, id: job.id]
      end)

    IO.puts("ack #{length(jobs)}")

    case SQS.delete_message_batch(name, jobs) |> ExAws.request() do
      {:ok, _} -> :ok
    end
  end

  def ack(queue, job) do
    name = queue.config |> Keyword.get(:queue_name)

    case SQS.delete_message(name, job.message.receipt_handle) |> ExAws.request() do
      {:ok, _} -> :ok
    end
  end

  def nack(queue, job, message) do
    name = queue.config |> Keyword.get(:queue_name)
    intervals = queue.config |> Keyword.get(:retry_intervals)

    %{receipt_handle: receipt_handle, attributes: %{"approximate_receive_count" => count}} =
      job.message

    retries = count - 1
    interval = Enum.at(intervals, retries)

    if interval != nil do
      case SQS.change_message_visibility(name, receipt_handle, interval) |> ExAws.request() do
        {:ok, _} -> :ok
      end
    else
      job = %Job{job | status: "dead", error_message: message, message: nil}
      dead_queue_name = queue.config |> Keyword.get(:dead_queue_name)

      dead_queue = queue.config |> Keyword.get(:dead_queue)
      :ok = dead_queue.push(job.module, job.args)

      case SQS.delete_message(name, receipt_handle) |> ExAws.request() do
        {:ok, _} ->
          Logger.error("#{job.id} moved to dead #{job.message}")
          :ok
      end
    end
  end

  defp queue_attributes_to_info(%{body: %{attributes: attributes}}) do
    %Info{
      pending: attributes[:approximate_number_of_messages],
      delayed: attributes[:approximate_number_of_messages_delayed],
      running: attributes[:approximate_number_of_messages_not_visible]
    }
  end

  def push(queue, jobs) when is_list(jobs) do
    name = queue.config |> Keyword.get(:queue_name)

    jobs
    |> Enum.chunk_every(10)
    |> Enum.each(fn chunk ->
      start = :os.system_time(:milli_seconds)

      payload =
        Enum.map(chunk, fn
          {module, args} ->
            job = Job.new(queue, module, args)
            [id: job.id, message_body: job |> encode]

          {module, args, opts} ->
            job = Job.new(queue, module, args)

            opts
            |> Keyword.put(:id, job.id)
            |> Keyword.put(:message_body, job |> encode)
        end)

      case SQS.send_message_batch(name, payload) |> ExAws.request() do
        {:ok, _} ->
          Logger.info(
            "push=#{length(payload)} runtime=#{:os.system_time(:milli_seconds) - start}ms"
          )

          :ok
      end
    end)
  end

  def push(queue, module, args, opts \\ []) do
    start = :os.system_time(:milli_seconds)
    name = queue.config |> Keyword.get(:queue_name)
    job = Job.new(queue, module, args)

    case SQS.send_message(name, job |> encode, opts) |> ExAws.request() do
      {:ok, _} ->
        Logger.info(
          "push=#{module} args=#{inspect(args)} runtime=#{:os.system_time(:milli_seconds) - start}ms"
        )

        :ok
    end
  end

  def dead_ack(queue, %Job{message: %{receipt_handle: receipt_handle}}) do
    name = queue.config |> Keyword.get(:dead_queue_name)

    case SQS.delete_message(name, receipt_handle) |> ExAws.request() do
      {:ok, _} -> :ok
    end
  end

  def dead_push(queue, job) do
    start = :os.system_time(:milli_seconds)
    name = queue.config |> Keyword.get(:dead_queue_name)

    case SQS.send_message(name, job |> encode) |> ExAws.request() do
      {:ok, _} ->
        Logger.info(
          "[dead queue] #{job.mod} args=#{inspect(job.args)} runtime=#{
            :os.system_time(:milli_seconds) - start
          }ms"
        )

        :ok
    end
  end

  def dead_retry(queue, job) do
    :ok = queue.push(job.module, job.args)
    name = queue.config |> Keyword.get(:dead_queue_name)

    case SQS.delete_message(name, job.message.receipt_handle) |> ExAws.request() do
      {:ok, _} -> :ok
    end
  end

  def dead(queue) do
    # queue_name = queue.config |> Keyword.get(:dead_queue_name)
    queue_name = queue.config |> Keyword.get(:queue_name)

    {:ok, response} =
      SQS.receive_message(
        queue_name,
        wait_time_seconds: 0,
        max_number_of_messages: 10,
        attribute_names: :all
      )
      |> ExAws.request()

    {:ok, decode_response(queue, response)}
  end

  def pop(queue, limit) do
    start = :os.system_time(:milli_seconds)
    queue_name = queue.config |> Keyword.get(:queue_name)
    queue_wait_time_seconds = queue.config |> Keyword.get(:queue_wait_time_seconds, 20)

    limit =
      cond do
        limit > 10 -> 10
        limit < 1 -> 1
        true -> limit
      end

    {:ok, response} =
      SQS.receive_message(
        queue_name,
        wait_time_seconds: queue_wait_time_seconds,
        max_number_of_messages: limit,
        attribute_names: :all
      )
      |> ExAws.request()

    jobs = decode_response(queue, response)

    Logger.debug(
      "pop=#{limit} received=#{length(jobs)} runtime=#{:os.system_time(:milli_seconds) - start}ms"
    )

    {:ok, jobs}
  end

  defp decode_response(_queue, %{body: %{messages: messages}}) do
    Enum.map(messages, fn %{body: body, attributes: attributes} = message ->
      job = decode(body)

      %Job{
        job
        | message: message,
          # first try is not counted as an error
          error_count: attributes["approximate_receive_count"] - 1
      }
    end)
  end

  def encode(job) do
    job
    |> Encoder.encode()
    |> Base.encode64()
  end

  # json jobs... not ours
  def decode("{" <> payload) do
    %Job{payload: "{" <> payload}
  end

  def decode(payload) do
    payload
    |> Base.decode64!()
    |> Encoder.decode()
  end
end
