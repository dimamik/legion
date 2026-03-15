defmodule Legion.AgentServer do
  @moduledoc """
  GenServer that maintains conversation history for a long-lived agent.

  Holds the message history across multiple turns. Each `call` or `cast`
  appends the user message and runs `Executor` to completion (blocking).

  ## Usage

      {:ok, pid} = Legion.start_link(MyAgent)
      {:ok, result} = Legion.call(pid, "Do something")
      Legion.cast(pid, "Follow-up (fire and forget)")
  """

  use GenServer

  alias Legion.{Executor, Telemetry}

  defstruct [:agent_module, :messages, :config, bindings: []]

  # Client API

  def start_link(agent_module, opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, {agent_module, opts}, gen_opts)
  end

  def call(agent, message, timeout \\ :infinity) do
    GenServer.call(agent, {:message, message}, timeout)
  end

  def cast(agent, message) do
    GenServer.cast(agent, {:message, message})
  end

  # Server callbacks

  @impl true
  def init({agent_module, opts}) do
    parent_run_id = Vault.get(:run_id)
    run_id = make_ref()

    Vault.unsafe_put(:run_id, run_id)
    Vault.unsafe_put(:parent_run_id, parent_run_id)

    for tool <- agent_module.tools() do
      Vault.unsafe_put(tool, agent_module.tool_config(tool))
    end

    system_prompt = agent_module.system_prompt()
    config = resolve_config(agent_module, opts)

    Telemetry.emit(
      [:legion, :agent, :started],
      %{system_time: System.system_time()},
      %{agent: agent_module}
    )

    state = %__MODULE__{
      agent_module: agent_module,
      messages: [%{role: "system", content: system_prompt}],
      config: config
    }

    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    Telemetry.emit(
      [:legion, :agent, :stopped],
      %{system_time: System.system_time()},
      %{agent: state.agent_module}
    )
  end

  @impl true
  def handle_call({:message, msg}, _from, state) do
    {reply, state} = handle_message(msg, state)
    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:message, msg}, state) do
    {_reply, state} = handle_message(msg, state)
    {:noreply, state}
  end

  defp handle_message(msg, state) do
    {status, value, final_messages, final_bindings} =
      Telemetry.span(
        [:legion, :agent, :message],
        %{agent: state.agent_module, message: msg},
        fn ->
          messages = state.messages ++ [%{role: "user", content: stringify(msg)}]
          prev_count = Enum.count(messages, &(&1[:role] == "assistant"))
          initial_bindings = if state.config[:share_bindings], do: state.bindings, else: []

          {status, value, msgs, _final_bindings} =
            result = Executor.run(state.agent_module, messages, state.config, initial_bindings)

          iterations = Enum.count(msgs, &(&1[:role] == "assistant")) - prev_count
          {result, %{iterations: iterations, status: status, result: value}}
        end
      )

    {{status, value}, %{state | messages: final_messages, bindings: final_bindings}}
  end

  defp stringify(msg) when is_binary(msg), do: msg
  defp stringify(msg), do: inspect(msg, pretty: true, limit: :infinity)

  defp resolve_config(agent_module, opts) do
    app_config = Application.get_env(:legion, :config, %{})

    call_config = Map.new(opts)

    Map.merge(app_config, Map.merge(agent_module.config(), call_config))
  end
end
