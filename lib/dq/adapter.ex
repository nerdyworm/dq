defmodule DQ.Adapter do
  @moduledoc """
  This module specifies the adapter API that a Queue is required to implement
  """

  @type t :: module

  @typep queue :: DQ.Queue.t
  @typep job :: DQ.Job.t
  @typep info :: DQ.Info.t

  @callback push(queue, list(job)) :: :ok | {:error, any}
  @callback push(queue, job) :: :ok | {:error, any}
  @callback pop(queue, integer) :: {:ok, list(any)} | {:error, any}
  @callback ack(queue, job) :: :ok | {:error, any}
  @callback nack(queue, job, binary) :: :ok | {:error, any}
  @callback dead(queue, job) :: :ok | {:error, any}
  @callback info(queue) :: {:ok, info}
  @callback purge(queue) :: :ok
end

