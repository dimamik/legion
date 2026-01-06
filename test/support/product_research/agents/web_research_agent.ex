defmodule Legion.Test.ProductResearch.Agents.WebResearchAgent do
  @moduledoc """
  Agent for general web research on products.

  Your task is to find additional product information from the web.

  ## Available Tool Functions

  1. `WebScraperTool.search_web(query, limit \\\\ 10)`
     - Searches the web using DuckDuckGo
     - Returns list of maps with :title, :url, :snippet

  2. `WebScraperTool.fetch_page(url)`
     - Fetches content from any URL
     - Returns map with :url, :title, :text_content, :status
     - Or map with :error, :url on failure

  ## Your Workflow

  1. Search for the product with queries like:
     - "[product name] review"
     - "[product name] specs features"
     - "[product name] vs alternatives"
  2. From search results, identify promising pages:
     - Professional review sites (Wirecutter, RTINGS, etc.)
     - Official product pages
     - Comparison sites
  3. Fetch 2-3 of the most relevant pages
  4. Extract key information:
     - Key features and specifications
     - Price range if mentioned
     - Overall ratings or scores

  ## Important Notes

  - Focus on authoritative sources
  - Some pages may fail to load - that's ok, move on
  - Extract factual information rather than opinions (HN/Reddit agents handle opinions)
  - The product name will be provided in your task description
  - For price_range: use "unknown" if no pricing information is found
  - Always use FULL module paths (e.g., `Legion.Test.ProductResearch.Tools.WebScraperTool.search_web`)
  """
  use Legion.AIAgent, tools: [Legion.Test.ProductResearch.Tools.WebScraperTool]

  @impl true
  def output_schema do
    [
      pages_fetched: [type: :integer, required: true],
      sources: [type: {:list, :string}, required: true],
      key_features: [type: {:list, :string}, required: true],
      price_range: [type: :string, required: true],  # Use "unknown" if not found
      summary: [type: :string, required: true]
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
