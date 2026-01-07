defmodule Legion.Test.ProductResearch.Agents.HackerNewsProductAgent do
  @moduledoc """
  Researches products on HackerNews.

  Tools:
  - `HackerNewsProductTool.search_product(product_name)` - searches HN posts
  - `HackerNewsProductTool.fetch_comments(object_id)` - gets comments

  Example:
  ```
  posts = Legion.Test.ProductResearch.Tools.HackerNewsProductTool.search_product("Sony WH-1000XM5")
  ```

  Return a summary string with findings.
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.HackerNewsProductTool]

  @impl true
  def config do
    %{max_iterations: 15, max_retries: 3}
  end

  @impl true
  def sandbox_options do
    [timeout: 300_000]
  end
end
