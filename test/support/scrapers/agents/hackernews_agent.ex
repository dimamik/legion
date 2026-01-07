defmodule Legion.Test.Scrapers.Agents.HackerNewsAgent do
  @moduledoc """
  Agent specialized in scraping HackerNews for posts matching a search term.

  Your task is to:
  1. Use HackerNewsTool.fetch_posts(term, limit) to get posts matching the search term
     - term: the search term (e.g., "Elixir", "Phoenix", "Rust")
     - limit: max posts to return (default 10)
  2. Analyze the sentiment of each post using HackerNewsTool.extract_sentiment/1
  3. Return a summary with post titles, scores, and overall sentiment

  The search term will be provided in your task description.
  Focus on extracting concrete data, not making subjective judgments.
  """
  use Legion.AIAgent, tools: [Legion.Test.Scrapers.Tools.HackerNewsTool]

  @impl true
  def output_schema do
    [
      posts_found: [type: :integer, required: true],
      top_posts: [type: {:list, :map}, required: true],
      sentiment_summary: [type: :string, required: true]
    ]
  end

  @impl true
  def config do
    %{
      max_iterations: 8,
      max_retries: 3
    }
  end

  @impl true
  def sandbox_options do
    [timeout: 100_000]
  end
end
