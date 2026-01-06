defmodule Legion.Test.ProductResearch.Agents.WebResearchAgent do
  @moduledoc """
  General web research on products.

  Tools:
  - `WebScraperTool.search_web(query)` - searches with DuckDuckGo
  - `WebScraperTool.fetch_page(url)` - fetches page content

  Example:
  ```
  results = Legion.Test.ProductResearch.Tools.WebScraperTool.search_web("Sony WH-1000XM5 review")
  ```

  Return a summary string with key findings.
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.WebScraperTool]

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
