defmodule QueueAdapterCase do
  use ExUnit.CaseTemplate

  alias DQ.Info

  defmodule TestCommand do
    def run(process) when is_atom(process) do
      Process.send_after(process, :ran, 100)
      :ok
    end

    def run(process) do
      run(process |> String.to_existing_atom)
    end
  end

  #defmodule TestNackCommand do
    #def run(process, uid) do
      #Process.send_after("#{process}" |> String.to_existing_atom, uid, 0)
      #:timer.sleep(100)
      #raise "Nacking the things: #{uid}"
    #end

    #def run(process, uid, "BE OK NOW") do
      #Process.send_after("#{process}" |> String.to_existing_atom, uid, 0)
      #:ok
    #end
  #end

  using do
    quote do
      test "shows info", %{queue: queue, process: process} do
        assert {:ok, %Info{}} = queue.info()
      end

      test "can run a job", %{queue: queue, process: process} do
        :ok = queue.push(TestCommand, [process])
        assert_receive :ran, 10_000
      end

      test "can run multiple jobs", %{queue: queue, process: process} do
        pairs =
          Enum.map(1..5, fn(_) ->
            {TestCommand, [process]}
          end)

        assert :ok = queue.push(pairs)
        Enum.each(1..5, fn(_) ->
          assert_receive :ran, 10_000
        end)
      end

      #test "retrying dead letters", %{queue: queue, process: process} do
        #uid = DQ.new_id
        #assert :ok = queue.push(TestNackCommand, [process, uid])
        #assert_receive uid, 5000
        #:timer.sleep(1000) # runs through retries, test is setup for max one recieve

        #{:ok, commands} = queue.dead
        #Enum.each(commands, fn(command) ->
          #command = %{command | args: command.args ++ ["BE OK NOW"]}
          #:ok = queue.dead_retry(command)
        #end)

        #assert {:ok, []} = queue.dead
      #end
    end
  end
end
