defmodule Legion.Tools.AgentTool do
  @moduledoc """
  Built-in tool for spawning and communicating with other Legion agents.

  This tool allows agents to delegate tasks to sub-agents, enabling
  hierarchical agent architectures.

  ## Configuration

  Control which agents can be spawned via `tool_options/1`:

      defmodule MyApp.OrchestratorAgent do
        use Legion.AIAgent, tools: [Legion.Tools.AgentTool, ...]

        @impl true
        def tool_options(Legion.Tools.AgentTool) do
          %{
            allowed_agents: [MyApp.WorkerAgent, MyApp.HelperAgent]
          }
        end
      end

  Set `allowed_agents: :all` (default) to allow spawning any agent.
  """

  use Legion.Tool

  @doc """
  Interacts with other agents.

  Can be used to spawn one-off agents or communicate with running agents.

  ## One-off Agent Execution

  Spawns a new agent, executes the task, and returns the result.

      Legion.Tools.AgentTool.call(MyApp.WorkerAgent, "Process this data")

  **Parameters:**
  - `agent_module`: The agent module to spawn (must implement Legion.AIAgent)
  - `task`: The task string for the agent to execute

  **Returns:**
  - `{:ok, result}` - Agent completed successfully
  - `{:error, message}` - Agent not in allowed list
  - `{:cancel, reason}` - Agent was cancelled

  ## Long-lived Agent Communication

  Sends a synchronous message to a running agent and waits for a response.

      Legion.Tools.AgentTool.call(agent_pid, "What is the status?")

  **Parameters:**
  - `pid`: The agent process identifier
  - `message`: The message to send

  **Returns:**
  - `{:ok, result}` - Agent responded with result
  - `{:cancel, reason}` - Agent was cancelled
  """
  @spec call(module(), String.t()) :: {:ok, any()} | {:error, String.t()} | {:cancel, atom()}
  def call(agent_module, task) when is_atom(agent_module) do
    opts = Vault.get(__MODULE__, %{})
    allowed = Map.get(opts, :allowed_agents, :all)

    if allowed?(agent_module, allowed) do
      Legion.execute(agent_module, task)
    else
      allowed_str = if allowed == :all, do: "all", else: Enum.join(allowed, ", ")
      {:error, "Agent #{inspect(agent_module)} is not allowed. Allowed agents: #{allowed_str}"}
    end
  end

  @spec call(pid(), String.t()) :: {:ok, any()} | {:cancel, atom()}
  def call(pid, message) when is_pid(pid) do
    Legion.call(pid, message)
  end

  @doc """
  Starts a long-lived agent and returns its pid.

  The agent is started with the given initial task and can receive
  further messages via `cast/2` and `call/2`.

  ## Parameters
    - agent_module: The agent module to start
    - initial_task: The initial task for the agent

  ## Returns
    - `{:ok, pid}` - Agent started successfully
    - `{:error, message}` - Agent not in allowed list (message includes allowed agents)

  ## Example

      {:ok, pid} = Legion.Tools.AgentTool.start_link(MyApp.AssistantAgent, "Initialize")
  """
  @spec start_link(module(), String.t()) :: {:ok, pid()} | {:error, String.t()}
  def start_link(agent_module, initial_task) do
    opts = Vault.get(__MODULE__, %{})
    allowed = Map.get(opts, :allowed_agents, :all)

    if allowed?(agent_module, allowed) do
      Legion.start_link(agent_module, initial_task)
    else
      allowed_str = if allowed == :all, do: "all", else: Enum.join(allowed, ", ")
      {:error, "Agent #{inspect(agent_module)} is not allowed. Allowed agents: #{allowed_str}"}
    end
  end

  @doc """
  Sends an asynchronous message to a long-lived agent.

  Does not wait for a response.

  ## Parameters
    - pid: The agent process identifier
    - message: The message to send

  ## Returns
    - `:ok`

  ## Example

      Legion.Tools.AgentTool.cast(agent_pid, "Process the next batch")
  """
  @spec cast(pid(), String.t()) :: :ok
  def cast(pid, message) do
    Legion.cast(pid, message)
  end

  @doc false
  @impl true
  def dynamic_doc(opts) do
    case Map.get(opts, :allowed_agents) do
      nil ->
        nil

      :all ->
        "**Allowed Agents:** All agents are allowed."

      agents when is_list(agents) ->
        agent_list =
          Enum.map_join(agents, "\n", fn agent ->
            short_name = get_short_name(agent)
            "- `#{short_name}`"
          end)

        """
        **Allowed Agents:**
        #{agent_list}
        """
    end
  end

  @doc false
  @impl true
  def get_aliases(opts) do
    opts
    |> Map.get(:allowed_agents)
    |> aliases_from_allowed()
  end

  defp aliases_from_allowed(nil), do: []
  defp aliases_from_allowed(:all), do: []

  defp aliases_from_allowed(agents) when is_list(agents) do
    Enum.map(agents, fn agent ->
      module = normalize_agent(agent)
      {get_short_name(module), module}
    end)
  end

  defp aliases_from_allowed(_), do: []

  defp normalize_agent(agent) when is_binary(agent), do: String.to_existing_atom(agent)
  defp normalize_agent(agent) when is_atom(agent), do: agent

  defp get_short_name(module) when is_atom(module) or is_binary(module) do
    module |> Module.split() |> List.last() |> String.to_atom()
  end

  defp allowed?(_agent_module, :all), do: true

  defp allowed?(agent_module, allowed_list) do
    to_string(agent_module) in allowed_list
  end

  @doc false
  @impl true
  def tool_description do
    "Spawns and communicates with other Legion agents for task delegation."
  end
end
