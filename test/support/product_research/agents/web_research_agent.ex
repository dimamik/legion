defmodule Legion.Test.ProductResearch.Agents.WebResearchAgent do
  @moduledoc """
  General web research. Navigate to relevant web pages and extract key information to answer the user's query.

  Example:
  ```
  results = Legion.Test.ProductResearch.Tools.WebScraperTool.search_web("Sony WH-1000XM5 pros and cons")
  ```

  Returns the answer to the user's query based on web research. Includes source links to back up findings. If uncertain - query more sources.
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
