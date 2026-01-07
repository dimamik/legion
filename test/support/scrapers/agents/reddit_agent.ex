defmodule Legion.Test.Scrapers.Agents.RedditAgent do
  @moduledoc """
  Agent specialized in scraping Reddit for posts matching a search term.

  Your task is to:
  1. Use RedditTool.fetch_posts(term, subreddit, limit) to get posts matching the search term
     - term: the search term (e.g., "Elixir", "Phoenix", "Rust")
     - subreddit: which subreddit to search (default "elixir")
     - limit: max posts to return (default 10)
  2. Analyze the sentiment of each post using RedditTool.extract_sentiment/1
  3. Return a summary with post titles, scores, and overall sentiment

  The search term and optional subreddit will be provided in your task description.
  Focus on extracting concrete data, not making subjective judgments.
  """
  use Legion.AIAgent, tools: [Legion.Test.Scrapers.Tools.RedditTool]

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
