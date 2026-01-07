defmodule Legion.Test.Scrapers.Agents.CoordinatorAgent do
  @moduledoc """
  Coordinator agent that spawns and manages scraper sub-agents.

  Your workflow:
  1. Call both HackerNews and Reddit scraper agents with specific tasks
  2. Collect results from both agents
  3. Analyze the combined results
  4. Return a comprehensive summary

  Available tools:
  - AgentTool.call(agent_module, task) - runs agent as one-off task, returns result directly

  Available agent modules:
  - Legion.Test.Scrapers.Agents.HackerNewsAgent - scrapes HackerNews
  - Legion.Test.Scrapers.Agents.RedditAgent - scrapes Reddit

  Example workflow in code:
    # Call agents with tasks that include the search term
    hn_result = AgentTool.call(Legion.Test.Scrapers.Agents.HackerNewsAgent, "Search for 'Elixir' posts, limit to 5")
    reddit_result = AgentTool.call(Legion.Test.Scrapers.Agents.RedditAgent, "Search for 'Elixir' posts, limit to 5")

    # Now analyze both results together

  Each agent returns: {:ok, %{posts_found: int, top_posts: list, sentiment_summary: string}}
  or {:cancel, reason}

  Your final output should provide concrete observations and statistics.
  """
  use Legion.AIAgent, tools: [Legion.Tools.AgentTool]

  @impl true
  def tool_options(Legion.Tools.AgentTool) do
    %{
      allowed_agents: [
        Legion.Test.Scrapers.Agents.HackerNewsAgent,
        Legion.Test.Scrapers.Agents.RedditAgent
      ]
    }
  end

  @impl true
  def output_schema do
    [
      total_posts: [type: :integer, required: true],
      overall_sentiment: [type: :string, required: true],
      key_topics: [type: {:list, :string}, required: true],
      visual_summary: [type: :string, required: true]
    ]
  end

  @impl true
  def config do
    %{
      max_iterations: 10,
      max_retries: 3
    }
  end

  @impl true
  def sandbox_options do
    [timeout: 100_000]
  end
end
