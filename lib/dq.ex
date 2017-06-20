defmodule DQ do
  def start_link do
    DQ.Server.start_link(queues())
  end

  def new_id(prefix \\ "DQ") do
    <<a::32>> = :crypto.strong_rand_bytes(4)
    "#{:io_lib.format("~s-~8.16.0b", [prefix, a])}"
  end

  defp queues do
    Application.get_env(:dq, :queues)
  end
end
