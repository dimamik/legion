defmodule Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent do
  @moduledoc """
  Coordinates and summarizes product research by delegating to specialized sub-agents. Always calls Legion tools to gather information instead of relying on internal knowledge. Try to execute tool calls via code as much as possible.

  Example:
  ```
  hn = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.HackerNewsProductAgent,
    "<thing> pros, cons, and alternatives"
  )
  reddit = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.RedditProductAgent,
    "<thing> pros, cons, and alternatives"
  )
  web = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.WebResearchAgent,
    "<thing> pros, cons, and alternatives"
  )
  [hn, reddit, web]
  ```

  Return a summary string with PROS, CONS, and ALTERNATIVES sections. You can call multiple agents at once. Use `WebResearchAgent` for general web research to dig deeper into things that concern you.
  """
  use Legion.AIAgent, tools: [Legion.Tools.AgentTool]

  @impl true
  def tool_options(Legion.Tools.AgentTool) do
    %{
      allowed_agents: [
        Legion.Test.ProductResearch.Agents.HackerNewsProductAgent,
        Legion.Test.ProductResearch.Agents.RedditProductAgent,
        Legion.Test.ProductResearch.Agents.WebResearchAgent
      ]
    }
  end

  @impl true
  def config do
    %{max_iterations: 20, max_retries: 3}
  end

  @impl true
  def sandbox_options do
    [timeout: 600_000]
  end
end
