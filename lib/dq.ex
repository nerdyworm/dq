defmodule DQ do
  def new_id(prefix \\ "DQ") do
    <<a::32>> = :crypto.strong_rand_bytes(4)
    "#{:io_lib.format("~s-~8.16.0b", [prefix, a])}"
  end
end
