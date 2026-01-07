defmodule Legion.Test.ProductResearch.Agents.RedditProductAgent do
  @moduledoc """
  Researches products on Reddit by searching posts and reading comments.

  Example workflow:
  ```
  posts = Legion.Test.ProductResearch.Tools.RedditProductTool.search_product("Sony WH-1000XM5", ["headphones"])
  # Then fetch comments from interesting posts
  comments = Legion.Test.ProductResearch.Tools.RedditProductTool.fetch_comments(post_permalink)
  ```

  IMPORTANT: Your final response must contain the ACTUAL findings from Reddit - real opinions, pros/cons, and issues mentioned by users. Do NOT return generic messages like "Summary generated" - return the actual summarized content with specific details from the posts and comments you found.
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.RedditProductTool]

  @impl true
  def config do
    %{max_iterations: 15, max_retries: 3}
  end

  @impl true
  def sandbox_options do
    [timeout: 300_000]
  end
end
