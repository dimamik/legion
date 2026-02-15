defmodule Legion.Test.Support.OrchestratorAgent do
  @moduledoc """
  An orchestrator agent that delegates research tasks to specialized sub-agents.

  Delegates HackerNews research to HackerNewsAgent and Reddit research to RedditAgent,
  then combines their findings.
  """
  use Legion.Agent

  alias Legion.Test.Support.{HackerNewsAgent, RedditAgent}

  def tools, do: [Legion.Tools.AgentTool]
  def config, do: %{model: "openai:gpt-4o-mini"}

  def tool_config(Legion.Tools.AgentTool), do: [agents: [HackerNewsAgent, RedditAgent]]
end
