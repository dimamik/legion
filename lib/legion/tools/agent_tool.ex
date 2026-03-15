defmodule Legion.Tools.AgentTool do
  @moduledoc """
  Built-in tool for delegating tasks to sub-agents.

  The calling agent must explicitly list allowed sub-agents via `tool_config/1`:

      def tool_config(Legion.Tools.AgentTool), do: [agents: [MyApp.WorkerAgent, MyApp.ResearchAgent]]
      def tool_config(_), do: []

  Only listed agents can be invoked. Attempts to call unlisted agents raise an error.

  ## Usage from agent code (executed in sandbox)

      Legion.Tools.AgentTool.call(MyApp.WorkerAgent, "Summarize this data")
  """

  use Legion.Tool

  alias Legion.AgentServer

  @doc """
  Starts a long-lived sub-agent process and returns `{:ok, pid}`.

  Raises if the agent is not in the allowed list.
  """
  def start_link(agent_module, task) when is_atom(agent_module) and is_binary(task) do
    check_allowed!(agent_module)

    with {:ok, pid} <- AgentServer.start_link(agent_module) do
      AgentServer.cast(pid, task)
      {:ok, pid}
    end
  end

  @doc """
  Sends a fire-and-forget message to a running agent pid.
  """
  def cast(pid, message) when is_pid(pid) and is_binary(message) do
    AgentServer.cast(pid, message)
  end

  @doc """
  Executes a one-off task on a module, or sends a synchronous message to a running agent pid.

  When called with a module, the sub-agent runs to completion and returns
  `{:ok, result}` or `{:cancel, reason}`. Raises if the agent is not in the allowed list.

  When called with a pid, sends a message to the running agent and blocks for the reply.
  """
  def call(agent_module, task) when is_atom(agent_module) and is_binary(task) do
    check_allowed!(agent_module)
    Legion.execute(agent_module, task)
  end

  def call(pid, message) when is_pid(pid) and is_binary(message) do
    AgentServer.call(pid, message)
  end

  defp check_allowed!(agent_module) do
    allowed = Vault.get(__MODULE__, [])[:agents] || []

    unless agent_module in allowed do
      raise ArgumentError,
            "agent #{inspect(agent_module)} is not allowed; allowed agents: #{inspect(allowed)}"
    end
  end
end
