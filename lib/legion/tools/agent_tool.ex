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

  @doc """
  Executes a sub-agent with the given task and returns the result.

  The sub-agent runs synchronously — this call blocks until
  the sub-agent completes or is cancelled.

  Raises if the agent is not in the allowed list.

  Returns `{:ok, result}` or `{:cancel, reason}`.
  """
  def call(agent_module, task) when is_atom(agent_module) and is_binary(task) do
    allowed = Vault.get(__MODULE__, [])[:agents] || []

    unless agent_module in allowed do
      raise ArgumentError,
            "agent #{inspect(agent_module)} is not allowed; allowed agents: #{inspect(allowed)}"
    end

    Legion.execute(agent_module, task)
  end
end
