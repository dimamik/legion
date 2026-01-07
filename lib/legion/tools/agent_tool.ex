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
  Spawns a one-off agent and waits for the result.

  The agent executes the given task and returns the result.
  This is a synchronous operation that blocks until complete.

  ## Parameters
    - agent_module: The agent module to spawn (must implement Legion.AIAgent)
    - task: The task string for the agent to execute

  ## Returns
    - `{:ok, result}` - Agent completed successfully
    - `{:error, message}` - Agent not in allowed list (message includes allowed agents)
    - `{:cancel, reason}` - Agent was cancelled

  ## Example

      Legion.Tools.AgentTool.call(MyApp.WorkerAgent, "Process this data")
  """
  @spec call(module(), String.t()) :: {:ok, any()} | {:error, String.t()} | {:cancel, atom()}
  def call(agent_module, task) do
    opts = Vault.get(__MODULE__, %{})
    allowed = Map.get(opts, :allowed_agents, :all)

    if allowed?(agent_module, allowed) do
      Legion.call(agent_module, task)
    else
      allowed_str = if allowed == :all, do: "all", else: Enum.join(allowed, ", ")
      {:error, "Agent #{inspect(agent_module)} is not allowed. Allowed agents: #{allowed_str}"}
    end
  end

  @doc """
  Starts a long-lived agent and returns its pid.

  The agent is started with the given initial task and can receive
  further messages via `send/2` and `ask/2`.

  ## Parameters
    - agent_module: The agent module to start
    - initial_task: The initial task for the agent

  ## Returns
    - `{:ok, pid}` - Agent started successfully
    - `{:error, message}` - Agent not in allowed list (message includes allowed agents)

  ## Example

      {:ok, pid} = Legion.Tools.AgentTool.start(MyApp.AssistantAgent, "Initialize")
  """
  @spec start(module(), String.t()) :: {:ok, pid()} | {:error, String.t()}
  def start(agent_module, initial_task) do
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

      Legion.Tools.AgentTool.send(agent_pid, "Process the next batch")
  """
  @spec send(pid(), String.t()) :: :ok
  def send(pid, message) do
    Legion.cast(pid, message)
  end

  @doc """
  Sends a synchronous message to a long-lived agent and waits for response.

  Blocks until the agent processes the message and returns a result.

  ## Parameters
    - pid: The agent process identifier
    - message: The message to send

  ## Returns
    - `{:ok, result}` - Agent responded with result
    - `{:cancel, reason}` - Agent was cancelled

  ## Example

      {:ok, response} = Legion.Tools.AgentTool.ask(agent_pid, "What is the status?")
  """
  @spec ask(pid(), String.t()) :: {:ok, any()} | {:cancel, atom()}
  def ask(pid, message) do
    Legion.send_sync(pid, message)
  end

  @doc false
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
  def get_aliases(opts) do
    case Map.get(opts, :allowed_agents) do
      nil -> []
      :all -> []
      agents when is_list(agents) ->
        Enum.map(agents, fn agent ->
          # Convert string back to atom if needed (stored as strings in Vault)
          module = if is_binary(agent), do: String.to_existing_atom(agent), else: agent
          short_name = get_short_name(module)
          {short_name, module}
        end)
    end
  end

  defp get_short_name(module) when is_atom(module) do
    module |> Module.split() |> List.last() |> String.to_atom()
  end

  defp get_short_name(module_string) when is_binary(module_string) do
    module_string |> Module.split() |> List.last() |> String.to_atom()
  end

  defp allowed?(_agent_module, :all), do: true

  defp allowed?(agent_module, allowed_list) do
    to_string(agent_module) in allowed_list
  end
end
