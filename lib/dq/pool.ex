defmodule DQ.Pool do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Logger

      alias DQ.{
        Collector,
        ConsumerSupervisor,
        Producer,
        TaskSupervisor
      }

      import DQ.Pool
      import Supervisor.Spec

      @config parse_config(__MODULE__, opts)
      @tasks Module.concat(__MODULE__, TaskSupervisor)
      @acks Module.concat(__MODULE__, AckCollector)
      @pushes Module.concat(__MODULE__, PushCollector)

      def start_link(opts) do
        queues = Keyword.get(opts, :queues, @config[:queues])
        ack_batch_size = Keyword.get(opts, :ack_batch_size, @config[:ack_batch_size])
        ack_deadline_ms = Keyword.get(opts, :ack_deadline_ms, @config[:ack_deadline_ms])
        push_batch_size = Keyword.get(opts, :push_batch_size, @config[:push_batch_size])
        push_deadline_ms = Keyword.get(opts, :push_deadline_ms, @config[:push_deadline_ms])
        pool = __MODULE__

        children = [
          worker(
            Collector,
            [[name: @acks, func: :ack, max: ack_batch_size, deadline_ms: ack_deadline_ms]],
            id: :acks
          ),
          worker(
            Collector,
            [[name: @pushes, func: :push, max: push_batch_size, deadline_ms: push_deadline_ms]],
            id: :pushes
          ),
          worker(DQ.Server.WeightedRoundRobin, [queues, pool]),
          worker(Producer, [pool]),
          supervisor(ConsumerSupervisor, [pool]),
          supervisor(Task.Supervisor, [[name: @tasks]])
        ]

        Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
      end

      def config do
        @config
      end

      def acks do
        @acks
      end

      def pushes do
        @acks
      end

      def after_empty_result_ms do
        @config[:after_empty_result_ms]
      end

      def next_queue do
        DQ.Server.WeightedRoundRobin.next_queue(__MODULE__)
      end

      def peak do
        DQ.Server.WeightedRoundRobin.peak(__MODULE__)
      end

      def task_supervisor do
        Module.concat(__MODULE__, TaskSupervisor)
      end

      def start_task(job) do
        Task.Supervisor.async_nolink(@tasks, DQ.Worker, :run, [job])
      end

      def batch_ack(queue, job) do
        :ok = Collector.collect(@acks, queue, job)
      end

      def async_batch_ack(queue, job) do
        :ok = Collector.async_collect(@acks, queue, job)
      end

      def batch_push(queue, job) do
        :ok = Collector.collect(@pushes, queue, job)
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor,
          restart: :permanent,
          shutdown: 500
        }
      end
    end
  end

  def parse_config(pool, options) do
    otp_app = Keyword.fetch!(options, :otp_app)
    config = Application.get_env(otp_app, pool, [])

    defaults = [
      after_empty_result_ms: 5000,
      min_demand: 0,
      max_demand: 1,
      queues: [],
      ack_batch_size: 10,
      ack_deadline_ms: 100,
      push_batch_size: 10,
      push_deadline_ms: 1000
    ]

    config = Keyword.merge(defaults, config)
    config = Keyword.merge(config, options)

    config
  end
end
