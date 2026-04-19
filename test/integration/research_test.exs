defmodule Legion.Integration.ResearchTest do
  @moduledoc """
  Integration test: research a topic across HackerNews and Reddit.

  Skipped by default to avoid external API calls and LLM costs.
  Run with:

      mix test test/integration/research_test.exs --include integration
  """
  use ExUnit.Case, async: true

  alias Legion.Test.Support.ResearchAgent

  @moduletag :integration
  @moduletag timeout: 300_000

  setup do
    unless System.get_env("OPENAI_API_KEY"), do: raise("OPENAI_API_KEY not set")
    :ok
  end

  test "researches Elixir across HackerNews and Reddit" do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Research Integration Test")
    IO.puts(String.duplicate("=", 60))

    task = """
    Research what people are saying about Elixir programming language.
    Use HackerNewsTool.fetch_posts/2 to get posts from HackerNews and
    RedditTool.fetch_posts/3 to get posts from r/elixir.
    Fetch up to 5 posts from each platform.
    Then analyze sentiment for each post using the extract_sentiment/1 functions.
    Summarize your findings: how many posts found, general sentiment, and notable topics.
    """

    result = Legion.execute(ResearchAgent, task)

    IO.puts("\nResult: #{inspect(result, pretty: true, limit: 20)}")
    IO.puts(String.duplicate("=", 60) <> "\n")

    assert match?({:ok, _}, result) or match?({:cancel, _}, result)
  end
end
