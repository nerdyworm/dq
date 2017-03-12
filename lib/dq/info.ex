defmodule DQ.Info do
  @type t :: module
  defstruct pending: 0, running: 0, delayed: 0, dead: 0
end

