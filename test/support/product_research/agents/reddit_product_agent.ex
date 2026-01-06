defmodule Legion.Test.ProductResearch.Agents.RedditProductAgent do
  @moduledoc """
  Agent specialized in researching products on Reddit.

  Your task is to thoroughly research a product using Reddit discussions.

  ## Available Tool Functions

  1. `RedditProductTool.search_product(product_name, subreddits \\\\ [...], limit \\\\ 15)`
     - Searches Reddit for posts about the product
     - Default subreddits: ["technology", "gadgets", "BuyItForLife", "ProductReviews"]
     - Returns list of maps with :title, :url, :score, :selftext, :subreddit, :num_comments, :permalink

  2. `RedditProductTool.fetch_comments(permalink, limit \\\\ 25)`
     - Fetches comments from a Reddit post
     - Takes the permalink from search results
     - Returns list of comment text strings

  ## Your Workflow

  1. Choose appropriate subreddits based on product type:
     - Tech products: ["technology", "gadgets", "hardware"]
     - Audio: ["headphones", "audiophile", "BudgetAudiophile"]
     - Software: ["software", "SaaS", "selfhosted"]
     - General: ["BuyItForLife", "ProductReviews", "Frugal"]
  2. Search for the product using search_product()
  3. For the top 2-3 most relevant/popular posts, fetch their comments
  4. Analyze all gathered text to identify:
     - Pros: positive aspects users mention
     - Cons: negative aspects, complaints, issues
     - Alternatives: other products users recommend
  5. Summarize the overall sentiment

  ## Important Notes

  - Reddit users tend to be very detailed in their feedback
  - Pay attention to upvote counts as indicators of agreement
  - Look for "I switched from X to Y" patterns for alternatives
  - The product name will be provided in your task description
  - Always use FULL module paths (e.g., `Legion.Test.ProductResearch.Tools.RedditProductTool.search_product`)
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.RedditProductTool]

  @impl true
  def output_schema do
    [
      posts_found: [type: :integer, required: true],
      subreddits_searched: [type: {:list, :string}, required: true],
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
