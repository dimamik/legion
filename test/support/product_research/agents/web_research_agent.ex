defmodule Legion.Test.ProductResearch.Agents.WebResearchAgent do
  @moduledoc """
  General web research. Navigate to relevant web pages and extract key information to answer the user's query.

  Example workflow:
  ```
  results = Legion.Test.ProductResearch.Tools.WebScraperTool.search_web("Sony WH-1000XM5 pros and cons")
  # Read specific pages for more details
  page = Legion.Test.ProductResearch.Tools.WebScraperTool.fetch_page(url)
  ```

  IMPORTANT: Your final response must contain the ACTUAL findings from web research - real facts, specs, reviews, pros/cons with source URLs. Do NOT return generic messages like "Summary generated" - return the actual summarized content with specific details and source links from the pages you found.
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.WebScraperTool]

  @impl true
  def config do
    %{max_iterations: 15, max_retries: 3}
  end

  @impl true
  def sandbox_options do
    [timeout: 300_000]
  end
end
