defmodule DQ.Encoder do
  def decode(nil) do
    {nil, nil}
  end

  def decode("") do
    {nil, nil}
  end

  def decode(payload) do
    :erlang.binary_to_term(payload)
  end

  def encode(payload) do
    :erlang.term_to_binary(payload)
  end
end
