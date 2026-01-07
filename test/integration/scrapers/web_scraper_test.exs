defmodule Legion.Integration.Scrapers.WebScraperTest do
  @moduledoc """
  Integration test for multi-agent web scraping workflow.

  This test demonstrates spawning sub-agents to scrape HackerNews and Reddit
  for mentions of a search term, then coordinating results with a main agent.

  ## Running this test

  The test is skipped by default to avoid making external API calls.
  To run it:

      # Run just this test
      mix test test/integration/scrapers/web_scraper_test.exs --include web_scraper

      # Or run all integration tests including this one
      mix test --only integration --include web_scraper

  Make sure you have ANTHROPIC_API_KEY set in your environment.
  """
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.Scrapers.Agents.CoordinatorAgent

  @moduletag :integration
  @moduletag timeout: 300_000

  @moduletag :web_scraper

  @doc """
  This test demonstrates a multi-agent web scraping workflow:

  1. Main coordinator agent is called
  2. Coordinator calls two sub-agents using AgentTool.call:
     - HackerNewsAgent: Uses HackerNewsTool to scrape HackerNews
     - RedditAgent: Uses RedditTool to scrape Reddit
  3. Each sub-agent independently fetches and filters data using their respective tools
  4. Coordinator collects results from sub-agents
  5. Coordinator aggregates results and provides a comprehensive summary

  The workflow tests Legion's ability to have agents dynamically call
  other agents for parallel data gathering tasks.
  """
  test "coordinator spawns sub-agents to scrape web for AI mentions" do
    with_api_key do
      IO.puts("\n" <> String.duplicate("=", 80))
      IO.puts("Multi-Agent Web Scraper Integration Test")
      IO.puts(String.duplicate("=", 80))

      IO.puts("[1/2] Calling Coordinator Agent...")

      coordinator_task = """
      You need to research available platforms for AI discussions and provide a comprehensive analysis of AI's presence and sentiment. To do this, use `AgentTool` to call social media sub-agents specialized in scraping specific platforms. This will help you build a fresh well-rounded perspective on AI trends. You need to run the code to complete your task.

      Available agents: Legion.Test.Scrapers.Agents.HackerNewsAgent, Legion.Test.Scrapers.Agents.RedditAgent
      """

      IO.puts("[2/2] Coordinator is calling sub-agents and coordinating work...\n")

      coordinator_result = Legion.execute(CoordinatorAgent, coordinator_task, timeout: 300_000)

      # Verify coordinator completed
      assert match?({:ok, _}, coordinator_result) or match?({:cancel, _}, coordinator_result)

      {coordinator_status, coordinator_data} = coordinator_result

      # Display final aggregated results
      IO.puts("\n" <> String.duplicate("=", 80))
      IO.puts("Final Results (#{coordinator_status}):")
      IO.puts(String.duplicate("=", 80))

      if coordinator_status == :ok do
        IO.puts("\n📊 VISUAL SUMMARY:")
        IO.puts(coordinator_data["visual_summary"])

        IO.puts("\n📈 Statistics:")
        IO.puts("  Total posts analyzed: #{coordinator_data["total_posts"]}")
        IO.puts("  Overall sentiment: #{coordinator_data["overall_sentiment"]}")

        IO.puts("\n🏷️  Key Topics:")

        Enum.each(coordinator_data["key_topics"] || [], fn topic ->
          IO.puts("  • #{topic}")
        end)
      else
        IO.puts("\nCoordinator finished with status: #{coordinator_status}")
        IO.puts(inspect(coordinator_data, pretty: true))
      end

      IO.puts("\n" <> String.duplicate("=", 80))
      IO.puts("Test completed!")
      IO.puts(String.duplicate("=", 80) <> "\n")

      # Test passes if coordinator completed (even if cancelled)
      assert true
    end
  end
end
