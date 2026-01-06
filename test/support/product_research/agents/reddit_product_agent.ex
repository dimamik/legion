defmodule Legion.Test.ProductResearch.Agents.RedditProductAgent do
  @moduledoc """
  Researches products on Reddit.

  Tools:
  - `RedditProductTool.search_product(product_name, subreddits)` - searches Reddit
  - `RedditProductTool.fetch_comments(permalink)` - gets comments

  Example:
  ```
  posts = Legion.Test.ProductResearch.Tools.RedditProductTool.search_product("Sony WH-1000XM5", ["headphones"])
  ```

  Return a summary string with findings.
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.RedditProductTool]

  @impl true
  def config do
    %{max_iterations: 15, max_retries: 3}
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
