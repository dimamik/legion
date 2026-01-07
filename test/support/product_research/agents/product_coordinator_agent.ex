defmodule Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent do
  @moduledoc """
  Coordinates product research by delegating to specialized sub-agents, then synthesizes their findings into a comprehensive summary.

  Example workflow:
  ```
  hn_result = Legion.Tools.AgentTool.call(HackerNewsProductAgent, "<product> reviews")
  reddit_result = Legion.Tools.AgentTool.call(RedditProductAgent, "<product> opinions")
  web_result = Legion.Tools.AgentTool.call(WebResearchAgent, "<product> specs and reviews")
  [hn_result, reddit_result, web_result]
  ```

  After gathering results from sub-agents, synthesize their findings into a final summary with PROS, CONS, and ALTERNATIVES sections. The sub-agents return actual content - extract and combine the key insights from each source into your response.

  IMPORTANT: Your final response must be a comprehensive summary that combines the actual findings from all sub-agents. Do NOT return the raw agent results or generic messages - synthesize the content into a coherent summary.
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
