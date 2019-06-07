defmodule DQ.Queue do
  @moduledoc """
  Documentation for DQ.Queue
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Logger

      import DQ.Queue
      {adapter, config} = parse_config(__MODULE__, opts)

      @adapter adapter
      @config config
      @queue __MODULE__

      def info do
        @adapter.info(@queue)
      end

      def ack(job) do
        @adapter.ack(@queue, job)
      end

      def nack(job, message) do
        @adapter.nack(@queue, job, message)
      end

      def push(pairs) when is_list(pairs) do
        @adapter.push(@queue, pairs)
      end

      def push(module, args, opts \\ []) do
        @adapter.push(@queue, module, args, opts)
      end

      def pop(limit) do
        {:ok, jobs} = @adapter.pop(@queue, limit)
        {:ok, Enum.map(jobs, &put_queue/1)}
      end

      def collect(job) do
        DQ.Collector.collect(job)
      end

      defp put_queue(job) do
        %{job | queue: @queue}
      end

      def dead do
        @adapter.dead(@queue)
      end

      def dead_ack(job) do
        @adapter.dead_ack(@queue, job)
      end

      def dead_retry(job) do
        @adapter.dead_retry(@queue, job)
      end

      def dead_purge do
        @adapter.dead_purge(@queue)
      end

      def config do
        @config
      end

      def encode(job) do
        @adapter.encode(job)
      end

      def decode(job) do
        @adapter.decode(job)
      end

      def middleware do
        @config[:middleware]
      end

      def weight do
        @config[:weight]
      end

      def job_struct do
        Keyword.get(@config, :struct, DQ.Job)
      end
    end
  end

  def default_middleware do
    [
      DQ.Middleware.Logger,
      DQ.Middleware.Executioner
    ]
  end

  def parse_config(queue, options) do
    otp_app = Keyword.fetch!(options, :otp_app)
    config = Application.get_env(otp_app, queue, [])

    defaults = [
      middleware: default_middleware(),
      retry_intervals: [2, 4, 8],
      weight: 1
    ]

    config = Keyword.merge(defaults, config)
    config = Keyword.merge(config, options)
    adapter = options[:adapter] || config[:adapter]

    unless adapter do
      raise ArgumentError,
            "missing :adapter configuration in " <>
              "config #{inspect(otp_app)}, #{inspect(adapter)}"
    end

    {adapter, config}
  end
end
