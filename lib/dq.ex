defmodule DQ do
  @moduledoc """
  Documentation for DQ.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Logger

      import DQ
      {adapter, config} = parse_config(__MODULE__, opts)

      @adapter adapter
      @config  config
      @queue  __MODULE__

      def start_link do
        @adapter.start_link(@queue)
      end

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
        @adapter.pop(@queue, limit)
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

      def producer_name,        do: Module.concat(__MODULE__, Producer)
      def supervisor_name,      do: Module.concat(__MODULE__, Supervisor)
      def task_supervisor_name, do: Module.concat(__MODULE__, TaskSupervisor)

      def middleware do
        @config[:middleware]
      end
    end
  end

  def default_middleware do
    [
      DQ.Middleware.Logger,
      DQ.Middleware.Executioner,
    ]
  end

  def parse_config(store, options) do
    otp_app = Keyword.fetch!(options, :otp_app)
    config = Application.get_env(otp_app, store, [])

    defaults = [
      queues: ["default"],
      middleware: default_middleware(),
      retry_intervals: [2, 4, 8],
      polling_ms: 5000,
    ]

    config = Keyword.merge(defaults, config)
    config = Keyword.merge(config, options)
    adapter = options[:adapter] || config[:adapter]

    unless adapter do
      raise ArgumentError, "missing :adapter configuration in " <>
      "config #{inspect otp_app}, #{inspect adapter}"
    end

    {adapter, config}
  end

  def new_id(prefix \\ "que") do
    <<a::32>> = :crypto.strong_rand_bytes(4)
    "#{:io_lib.format("~s-~8.16.0b", [prefix, a])}"
  end
end
