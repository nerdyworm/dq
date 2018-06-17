defmodule DQ.Pool do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Logger

      alias DQ.{
        Producer,
        ConsumerSupervisor,
        TaskSupervisor
      }

      import DQ.Pool
      import Supervisor.Spec

      @config parse_config(__MODULE__, opts)
      @tasks Module.concat(__MODULE__, TaskSupervisor)

      def start_link(queues) do
        pool = __MODULE__

        children = [
          # TODO - allow the manager strategy to be configurable
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
    end
  end

  def parse_config(pool, options) do
    otp_app = Keyword.fetch!(options, :otp_app)
    config = Application.get_env(otp_app, pool, [])

    defaults = [
      after_empty_result_ms: 5000,
      min_demand: 1,
      max_demand: 1
    ]

    config = Keyword.merge(defaults, config)
    config = Keyword.merge(config, options)

    config
  end
end