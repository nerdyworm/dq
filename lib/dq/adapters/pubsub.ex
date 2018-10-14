defmodule DQ.Adapters.Pubsub do
  alias DQ.{
    Info,
    Job,
    Encoder
  }

  def push(queue, module, args, _opts \\ []) do
    project_id = queue.config |> Keyword.get(:project_id)
    topic_id = queue.config |> Keyword.get(:topic_id)

    job = Job.new(queue, module, args)

    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    conn = GoogleApi.PubSub.V1.Connection.new(token.token)

    {:ok, %GoogleApi.PubSub.V1.Model.PublishResponse{messageIds: _ids}} =
      GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_topics_publish(
        conn,
        project_id,
        topic_id,
        body: %GoogleApi.PubSub.V1.Model.PublishRequest{
          messages: [
            %GoogleApi.PubSub.V1.Model.PubsubMessage{
              attributes: %{
                "count" => "1",
                "run_at" => "0"
              },
              data: encode(job)
            }
          ]
        }
      )

    :ok
  end

  # @callback pop(queue, integer) :: {:ok, list(any)} | {:error, any}
  def pop(queue, limit) do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    conn = GoogleApi.PubSub.V1.Connection.new(token.token)

    project_id = queue.config |> Keyword.get(:project_id)
    subscription_name = queue.config |> Keyword.get(:subscription_name)
    topic_id = queue.config |> Keyword.get(:topic_id)

    # Make a subscription pull
    {:ok, response} =
      GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_subscriptions_pull(
        conn,
        project_id,
        subscription_name,
        body: %GoogleApi.PubSub.V1.Model.PullRequest{
          maxMessages: limit
        }
      )

    jobs = decode_response(response)

    # kind of a hack
    #
    # There is no way to know how many times a message has been received
    # from the pubsub api.  So we re queue jobs with the correct attributes
    # set.  If the run_at is not yet passed we should just delayed the job
    # until it is.
    #
    now = DateTime.utc_now() |> DateTime.to_unix()

    jobs =
      Enum.filter(jobs, fn job ->
        run_at = Map.get(job.message.message.attributes || %{}, "run_at", "0")
        {run_at, ""} = Integer.parse(run_at)

        if run_at < now do
          true
        else
          {:ok, _response} =
            GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_subscriptions_modify_ack_deadline(
              conn,
              project_id,
              topic_id,
              body:
                %GoogleApi.PubSub.V1.Model.ModifyAckDeadlineRequest{
                  ackIds: [job.message.ackId],
                  ackDeadlineSeconds: run_at - now
                }
                |> IO.inspect()
            )

          false
        end
      end)

    {:ok, jobs}
  end

  defp decode_response(%{receivedMessages: messages}) when is_nil(messages) do
    []
  end

  defp decode_response(%{receivedMessages: messages}) when is_list(messages) do
    Enum.map(messages, fn message ->
      data = Base.decode64!(message.message.data)
      job = decode(data)
      %Job{job | id: message.message.messageId, message: message}
    end)
  end

  # @callback ack(queue, job) :: :ok | {:error, any}
  def ack(queue, job) do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    conn = GoogleApi.PubSub.V1.Connection.new(token.token)

    project_id = queue.config |> Keyword.get(:project_id)
    subscription_name = queue.config |> Keyword.get(:subscription_name)

    {:ok, %GoogleApi.PubSub.V1.Model.Empty{}} =
      GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_subscriptions_acknowledge(
        conn,
        project_id,
        subscription_name,
        body: %GoogleApi.PubSub.V1.Model.AcknowledgeRequest{
          ackIds: [job.message.ackId]
        }
      )

    :ok
  end

  # @callback nack(queue, job, binary) :: :ok | {:error, any}
  def nack(queue, job, message) do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    conn = GoogleApi.PubSub.V1.Connection.new(token.token)

    topic_id = queue.config |> Keyword.get(:topic_id)
    project_id = queue.config |> Keyword.get(:project_id)
    subscription_name = queue.config |> Keyword.get(:subscription_name)
    intervals = queue.config |> Keyword.get(:retry_intervals)

    # IO.inspect(job.message)
    count = Map.get(job.message.message.attributes || %{}, "count", "1")
    {count, ""} = Integer.parse(count)

    retries = count - 1
    interval = Enum.at(intervals, retries)

    if interval != nil do
      job_copy = %Job{job | message: nil, error_count: count, error_message: message}

      run_at =
        DateTime.utc_now()
        |> DateTime.to_unix()
        |> Kernel.+(interval)

      {:ok, %GoogleApi.PubSub.V1.Model.PublishResponse{messageIds: _ids}} =
        GoogleApi.PubSub.V1.Api.Projects.pubsub_projects_topics_publish(
          conn,
          project_id,
          topic_id,
          body: %GoogleApi.PubSub.V1.Model.PublishRequest{
            messages: [
              %GoogleApi.PubSub.V1.Model.PubsubMessage{
                attributes:
                  %{
                    "count" => "#{count + 1}",
                    "run_at" => "#{run_at}"
                  }
                  |> IO.inspect(),
                data: encode(job_copy)
              }
            ]
          }
        )

      :ok = ack(queue, job)
    else
      #   job = %Job{job | status: "dead", error_message: message, message: nil}
      #   dead_queue_name = queue.config |> Keyword.get(:dead_queue_name)

      #   case SQS.send_message(dead_queue_name, job |> encode) |> ExAws.request() do
      #     {:ok, _} ->
      #       case SQS.delete_message(name, receipt_handle) |> ExAws.request() do
      #         {:ok, _} ->
      #           Logger.error("#{job.id} moved to dead")
      #           :ok
      #       end
      #   end
      IO.puts("JOB IS DEAD!!!")
      :ok = ack(queue, job)
    end
  end

  # @callback dead(queue, job) :: :ok | {:error, any}
  # @callback info(queue) :: {:ok, info}
  # @callback purge(queue) :: :ok

  def encode(job) do
    job
    |> Encoder.encode()
    |> Base.encode64()
  end

  def decode("{" <> payload) do
    %Job{payload: "{" <> payload}
  end

  def decode(payload) do
    payload
    |> Encoder.decode()
  end
end
