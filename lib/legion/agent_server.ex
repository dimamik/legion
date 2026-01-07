defmodule Legion.AgentServer do
  @moduledoc """
  GenServer for long-lived Legion agents.

  Wraps the Executor to provide a stateful agent that maintains
  context between interactions. Can be supervised and added to
  supervision trees.

  ## Usage

      {:ok, pid} = Legion.start_link(MyAgent, "Initial task")
      Legion.cast(pid, "Follow-up message")
      {:ok, response} = Legion.call(pid, "Question")

  ## State

  The server maintains:
  - Agent module reference
  - Conversation context (messages history)
  - Configuration
  - Precomputed allowlist
  - Human input waiting state (for HumanTool)
  """

  use GenServer

  alias Legion.{Config, Executor}
  alias Legion.LLM.PromptBuilder
  alias Legion.Observability.Telemetry

  defstruct [
    :agent_module,
    :context,
    :config,
    :human_input_waiter
  ]

  @type t :: %__MODULE__{
          agent_module: module(),
          context: Executor.context(),
          config: Config.t(),
          human_input_waiter: {pid(), reference()} | nil
        }

  # Client API

  @doc """
  Starts a long-lived agent process.

  ## Options
    - `:name` - GenServer name registration
    - All other options are passed to Config.resolve/2
  """
  @spec start_link(module(), String.t(), keyword()) :: GenServer.on_start()
  def start_link(agent_module, initial_task, opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, {agent_module, initial_task, opts}, gen_opts)
  end

  @doc """
  Sends an asynchronous message to the agent.
  """
  @spec cast(GenServer.server(), String.t()) :: :ok
  def cast(agent, message) do
    GenServer.cast(agent, {:message, message})
  end

  @doc """
  Sends a synchronous message to the agent and waits for result.
  """
  @spec call(GenServer.server(), String.t() | {:respond, any()}, timeout()) ::
          {:ok, any()} | {:cancel, atom()}
  def call(agent, message, timeout \\ 30_000)

  def call(agent, {:respond, _} = message, timeout) do
    GenServer.call(agent, message, timeout)
  end

  def call(agent, message, timeout) do
    GenServer.call(agent, {:message, message}, timeout)
  end

  @doc """
  Requests human input (called from within HumanTool).

  This is called from the tool execution context and blocks until
  a response is received via Legion.call/3 with {:respond, response}.
  """
  @spec request_human_input(GenServer.server(), String.t(), atom()) :: any()
  def request_human_input(agent, question, type) do
    GenServer.call(agent, {:request_human_input, question, type}, :infinity)
  end

  # Server Callbacks

  @impl true
  def init({agent_module, initial_task, opts}) do
    config = Config.resolve(agent_module, opts)
    agent_info = agent_module.__legion_agent_info__()
    system_prompt = PromptBuilder.build_system_prompt(agent_module)

    # Set up Vault with tool options
    setup_vault(agent_module, agent_info.tools)

    context = %{
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: initial_task}
      ],
      iteration: 0,
      retry: 0
    }

    state = %__MODULE__{
      agent_module: agent_module,
      context: context,
      config: config,
      human_input_waiter: nil
    }

    # Run initial task asynchronously
    send(self(), :run_initial)

    {:ok, state}
  end

  @impl true
  def handle_info(:run_initial, state) do
    new_state = run_executor(state)
    {:noreply, new_state}
  end

  def handle_info({:executor_result, from, result}, state) do
    case result do
      {:ok, value, new_context} ->
        GenServer.reply(from, {:ok, value})
        {:noreply, %{state | context: new_context}}

      {:cancel, reason, new_context} ->
        GenServer.reply(from, {:cancel, reason})
        {:noreply, %{state | context: new_context}}
    end
  end

  @impl true
  def handle_cast({:message, message}, state) do
    new_state = process_message(state, message)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:message, message}, from, state) do
    # Store the caller to reply when execution completes
    new_state = process_message_sync(state, message, from)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:request_human_input, question, type}, from, state) do
    # Emit telemetry event
    Telemetry.emit(
      [:legion, :human, :input_required],
      %{system_time: System.system_time()},
      %{agent: state.agent_module, question: question, type: type}
    )

    # Store the waiter and suspend execution
    {:noreply, %{state | human_input_waiter: from}}
  end

  @impl true
  def handle_call({:respond, response}, _from, state) do
    case state.human_input_waiter do
      nil ->
        {:reply, {:error, :no_pending_request}, state}

      waiter ->
        # Emit telemetry
        Telemetry.emit(
          [:legion, :human, :input_received],
          %{system_time: System.system_time()},
          %{agent: state.agent_module}
        )

        # Reply to the waiting tool call
        GenServer.reply(waiter, response)

        {:reply, :ok, %{state | human_input_waiter: nil}}
    end
  end

  # Private functions

  defp setup_vault(agent_module, tools) do
    tools
    |> Enum.map(&build_tool_entry(agent_module, &1))
    |> Enum.into(%{})
    |> Vault.unsafe_merge()
  end

  defp build_tool_entry(agent_module, tool_module) do
    opts = agent_module.tool_options(tool_module)
    {tool_module, normalize_allowed_agents(opts)}
  end

  defp normalize_allowed_agents(opts) do
    case Map.get(opts, :allowed_agents) do
      agents when is_list(agents) ->
        Map.put(opts, :allowed_agents, Enum.map(agents, &to_string/1))

      _ ->
        opts
    end
  end

  defp process_message(state, message) do
    run_executor(state, message)
  end

  defp process_message_sync(state, message, from) do
    run_executor_sync(state, message, from)
  end

  defp run_executor(state, message \\ "") do
    # Set process variable for HumanTool access
    Process.put(:legion_agent_server, self())

    case Executor.continue(
           state.agent_module,
           state.context,
           message,
           state.config
         ) do
      {:ok, _result, new_context} ->
        %{state | context: new_context}

      {:cancel, _reason, new_context} ->
        %{state | context: new_context}
    end
  end

  defp run_executor_sync(state, message, from) do
    # Run in a spawned process to avoid blocking the GenServer
    parent = self()

    spawn(fn ->
      # Set process variable for HumanTool access
      Process.put(:legion_agent_server, parent)

      result =
        Executor.continue(
          state.agent_module,
          state.context,
          message,
          state.config
        )

      send(parent, {:executor_result, from, result})
    end)

    state
  end
end
