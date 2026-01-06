defmodule Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent do
  @moduledoc """
  Coordinates product research by delegating to specialized sub-agents. Always calls Legion tools to gather information instead of relying on internal knowledge. Try to execute tool calls via code as much as possible.

  Example:
  ```
  hn = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.HackerNewsProductAgent,
    "Research 'Sony WH-1000XM5' headphones"
  )
  reddit = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.RedditProductAgent,
    "Research 'Sony WH-1000XM5' headphones"
  )
  web = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.WebResearchAgent,
    "Research 'Sony WH-1000XM5' headphones"
  )
  [hn, reddit, web]
  ```

  Return a summary string with PROS, CONS, and ALTERNATIVES sections. Always rely on tool calls for information, you're only responsible for coordinating and summarizing. You can call multiple agents at once. Dig deep if the the information you found is not enough to provide full analysis.
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
    [
      timeout: 600_000,
      max_reductions: 500_000_000,
      stdio: :stdout,
      max_heap_size: 50_000_000
    ]
  end
end
