defmodule Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent do
  @moduledoc """
  Coordinator agent that orchestrates product research across multiple sources.

  Your task is to coordinate comprehensive product research by delegating to specialized sub-agents.

  ## Available Tool

  `Legion.Tools.AgentTool.call(agent_module, task)` - Runs an agent with the given task and returns its result.

  **IMPORTANT:** Always use FULL module paths in your code (e.g., `Legion.Tools.AgentTool.call`, not `AgentTool.call`).

  ## Available Sub-Agents

  1. `Legion.Test.ProductResearch.Agents.HackerNewsProductAgent`
     - Researches product on HackerNews
     - Returns: posts_found, comments_analyzed, pros, cons, alternatives_mentioned, sentiment_summary

  2. `Legion.Test.ProductResearch.Agents.RedditProductAgent`
     - Researches product on Reddit
     - Returns: posts_found, subreddits_searched, comments_analyzed, pros, cons, alternatives_mentioned, sentiment_summary

  3. `Legion.Test.ProductResearch.Agents.WebResearchAgent`
     - Researches product on the general web
     - Returns: pages_fetched, sources, key_features, price_range, summary

  ## Your Workflow

  1. Determine if the input is a **specific product** or a **category**:
     - Specific product: "Sony WH-1000XM5", "iPhone 15 Pro", "Keychron K2"
     - Category: "wireless headphones", "mechanical keyboards", "laptops under $1000"

  2. Call all three sub-agents with appropriate tasks:
     ```
     hn_result = Legion.Tools.AgentTool.call(
       Legion.Test.ProductResearch.Agents.HackerNewsProductAgent,
       "Research '[product]' - find discussions, extract pros, cons, and alternatives"
     )
     ```

  3. Collect and synthesize results from all agents

  4. Produce final output based on input type:

     **For specific product:**
     - Populate pros, cons, and alternatives fields
     - Set top_recommendations to empty list []
     - Write overall summary of sentiment and recommendation

     **For category:**
     - Populate top_recommendations with top 5 products (each with: name, reason, pros)
     - Set pros, cons, alternatives to empty lists []
     - Write overall summary of the category landscape

     **IMPORTANT:** ALL output fields must be populated. Use empty lists [] for fields that don't apply to your research type.

  ## Example Code

  ```elixir
  # Call sub-agents using FULL module paths
  hn = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.HackerNewsProductAgent,
    "Research 'Sony WH-1000XM5' headphones - find HN discussions, extract user opinions"
  )

  reddit = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.RedditProductAgent,
    "Research 'Sony WH-1000XM5' on Reddit - check r/headphones, r/audiophile"
  )

  web = Legion.Tools.AgentTool.call(
    Legion.Test.ProductResearch.Agents.WebResearchAgent,
    "Find web reviews and specs for 'Sony WH-1000XM5' headphones"
  )

  # Now analyze hn, reddit, and web results...
  ```

  ## Important Notes

  - Each sub-agent call may take 30-60 seconds
  - Sub-agents may return partial data if APIs are slow
  - Synthesize findings into actionable insights
  - Be specific in your pros/cons - avoid generic statements
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
  def output_schema do
    [
      research_type: [type: :string, required: true],
      product_or_category: [type: :string, required: true],
      sources_consulted: [type: :integer, required: true],
      # For single product research (return empty list if category research)
      pros: [type: {:list, :string}, required: true],
      cons: [type: {:list, :string}, required: true],
      alternatives: [type: {:list, :map}, required: true],
      # For category research (return empty list if single product research)
      top_recommendations: [type: {:list, :map}, required: true],
      overall_summary: [type: :string, required: true]
    ]
  end

  @impl true
  def config do
    %{
      max_iterations: 20,
      max_retries: 3
    }
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
