defmodule Legion.Tools.HumanToolTest do
  use ExUnit.Case, async: true

  alias Legion.Tools.HumanTool

  defmodule FakeHandler do
    use GenServer

    def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)

    def init(:ok), do: {:ok, %{}}

    def handle_info({:human_request, ref, from_pid, _question, _meta}, state) do
      send(from_pid, {:human_response, ref, "fake answer"})
      {:noreply, state}
    end
  end

  defmodule SilentHandler do
    use GenServer

    def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, :ok, opts)

    def init(:ok), do: {:ok, %{}}

    # intentionally does nothing
    def handle_info({:human_request, _ref, _from, _question, _meta}, state),
      do: {:noreply, state}
  end

  setup do
    {:ok, handler} = FakeHandler.start_link()
    Vault.unsafe_merge(%{Legion.Tools.HumanTool => [handler: handler]})
    :ok
  end

  test "ask/1 sends request to handler and returns the response" do
    assert HumanTool.ask("What is your name?") == "fake answer"
  end

  test "ask/1 passes question and run_id metadata to handler" do
    run_id = make_ref()
    test_pid = self()

    spy_pid =
      spawn(fn ->
        receive do
          {:human_request, ref, from_pid, question, meta} ->
            send(test_pid, {:captured, question, meta})
            send(from_pid, {:human_response, ref, "spy answer"})
        end
      end)

    Vault.unsafe_merge(%{Legion.Tools.HumanTool => [handler: spy_pid], run_id: run_id})

    assert HumanTool.ask("tell me something") == "spy answer"
    assert_receive {:captured, "tell me something", %{run_id: ^run_id}}
  end

  test "ask/1 raises when no handler is configured" do
    Vault.unsafe_merge(%{Legion.Tools.HumanTool => []})

    assert_raise ArgumentError, ~r/HumanTool requires a handler/, fn ->
      HumanTool.ask("hello?")
    end
  end

  test "ask/1 times out when handler never responds" do
    {:ok, silent} = SilentHandler.start_link()
    Vault.unsafe_merge(%{Legion.Tools.HumanTool => [handler: silent, timeout: 50]})

    assert_raise RuntimeError, ~r/timed out/, fn ->
      HumanTool.ask("are you there?")
    end

    GenServer.stop(silent)
  end
end
