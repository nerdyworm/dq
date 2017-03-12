defmodule DQ.Context do
  alias DQ.Context
  defstruct [
    assigns: %{},
    halted:  false,
    queue:   nil,
    job:     nil,
  ]

  def new(queue, job) do
    %__MODULE__{queue: queue, job: job}
  end

  def assign(%Context{assigns: assigns} = context, key, value) when is_atom(key) do
    %{context | assigns: Map.put(assigns, key, value)}
  end
end
