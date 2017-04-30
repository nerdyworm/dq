defmodule DQTest do
  use ExUnit.Case

  test "new_id" do
    assert String.starts_with?(DQ.new_id, "DQ")
    assert DQ.new_id != DQ.new_id
  end
end
