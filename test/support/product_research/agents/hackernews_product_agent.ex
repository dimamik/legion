defmodule Legion.Test.ProductResearch.Agents.HackerNewsProductAgent do
  @moduledoc """
  Agent specialized in researching products on HackerNews.

  Your task is to thoroughly research a product using HackerNews discussions.

  ## Available Tool Functions

  1. `HackerNewsProductTool.search_product(product_name, limit \\\\ 15)`
     - Searches HackerNews for posts about the product
     - Returns list of maps with :title, :url, :score, :text, :num_comments, :object_id

  2. `HackerNewsProductTool.fetch_comments(item_id, limit \\\\ 25)`
     - Fetches comments from a HackerNews story
     - Takes the object_id from search results
     - Returns list of comment text strings

  ## Your Workflow

  1. Search for the product using search_product()
  2. For the top 2-3 most relevant/popular posts, fetch their comments
  3. Analyze all the gathered text to identify:
     - Pros: positive aspects users mention
     - Cons: negative aspects, complaints, issues
     - Alternatives: other products users recommend instead
  4. Summarize the overall sentiment

  ## Important Notes

  - Focus on extracting concrete, specific feedback from real users
  - Look for recurring themes across multiple comments
  - Note any alternatives that are frequently mentioned
  - The product name will be provided in your task description
  - Always use FULL module paths (e.g., `Legion.Test.ProductResearch.Tools.HackerNewsProductTool.search_product`)
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.HackerNewsProductTool]

  @impl true
  def output_schema do
    [
      posts_found: [type: :integer, required: true],
      comments_analyzed: [type: :integer, required: true],
      pros: [type: {:list, :string}, required: true],
      cons: [type: {:list, :string}, required: true],
      alternatives_mentioned: [type: {:list, :string}, required: true],
      sentiment_summary: [type: :string, required: true]
    ]
  end

  @impl true
  def config do
    %{
      max_iterations: 15,
      max_retries: 3
    }
  end

  @impl true
  def sandbox_options do
    [
      timeout: 300_000,
      max_reductions: 100_000_000,
      stdio: :stdout,
      max_heap_size: 10_000_000
    ]
  end
end
