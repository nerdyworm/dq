defmodule DQ.Job do
  @derive {Poison.Encoder, except: [:payload, :message]}

  @type t :: module

  defstruct [
     id:                 nil,
     payload:            nil,
     module:             nil,
     args:               nil,
     queue:              "default",
     status:             "pending",
     error_count:         0,
     error_message:       nil,
     max_runtime_seconds: 30,
     message:            nil,
  ]

  def new(module, args) do
    %__MODULE__{id: DQ.new_id, module: module, args: args}
  end
end
