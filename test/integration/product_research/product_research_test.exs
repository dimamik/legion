defmodule Legion.Integration.ProductResearch.ProductResearchTest do
  @moduledoc """
  Integration test for multi-agent product research workflow.

  This test demonstrates:
  - Coordinator agent spawning specialized sub-agents
  - Parallel data gathering from HackerNews, Reddit, and web sources
  - Synthesizing research into actionable product recommendations

  ## Running this test

  The test is skipped by default to avoid making external API calls.
  To run it:

      # Run just this test
      mix test test/integration/product_research/product_research_test.exs --include product_research

      # Or run all integration tests including this one
      mix test --only integration --include product_research

  Make sure you have ANTHROPIC_API_KEY set in your environment.
  """
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent

  @moduletag :integration
  @moduletag timeout: 300_000
  @moduletag :product_research

  describe "single product research" do
    test "researches a specific product and returns pros, cons, and alternatives" do
      with_api_key do
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Single Product Research Integration Test")
        IO.puts(String.duplicate("=", 80))

        product_name = "Sony WH-1000XM5"

        coordinator_task = """
        Research the product "#{product_name}" thoroughly.

        This is a SPECIFIC PRODUCT research (not a category).

        Use AgentTool.call to delegate to these sub-agents:
        1. Legion.Test.ProductResearch.Agents.HackerNewsProductAgent - for HackerNews discussions
        2. Legion.Test.ProductResearch.Agents.RedditProductAgent - for Reddit discussions (try r/headphones, r/audiophile)
        3. Legion.Test.ProductResearch.Agents.WebResearchAgent - for general web reviews and specs

        After gathering data from all sources, synthesize and provide:
        - pros: List of positive aspects users mention
        - cons: List of negative aspects and complaints
        - alternatives: List of alternative products users recommend, each with a reason
        - overall_summary: Your synthesis of all findings

        Set research_type to "single_product" and product_or_category to "#{product_name}".
        """

        IO.puts("\n[1/2] Calling Coordinator Agent for product: #{product_name}")
        IO.puts("[2/2] Coordinator is delegating to sub-agents...\n")

        result = Legion.call(ProductCoordinatorAgent, coordinator_task, timeout: 300_000)

        assert match?({:ok, _}, result) or match?({:cancel, _}, result)

        {status, data} = result

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Product Research Results (#{status}):")
        IO.puts(String.duplicate("=", 80))

        if status == :ok do
          IO.puts("\nProduct: #{data["product_or_category"]}")
          IO.puts("Research Type: #{data["research_type"]}")
          IO.puts("Sources Consulted: #{data["sources_consulted"]}")

          IO.puts("\nPROS:")
          Enum.each(data["pros"] || [], fn pro ->
            IO.puts("  + #{pro}")
          end)

          IO.puts("\nCONS:")
          Enum.each(data["cons"] || [], fn con ->
            IO.puts("  - #{con}")
          end)

          IO.puts("\nALTERNATIVES:")
          Enum.each(data["alternatives"] || [], fn alt ->
            name = if is_map(alt), do: alt["name"] || inspect(alt), else: inspect(alt)
            reason = if is_map(alt), do: alt["reason"] || "", else: ""
            IO.puts("  * #{name}: #{reason}")
          end)

          IO.puts("\nOVERALL SUMMARY:")
          IO.puts(data["overall_summary"])
        else
          IO.puts("\nCoordinator finished with status: #{status}")
          IO.puts(inspect(data, pretty: true))
        end

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Test completed!")
        IO.puts(String.duplicate("=", 80) <> "\n")

        assert true
      end
    end
  end

  describe "category research" do
    test "researches a product category and returns top 5 recommendations" do
      with_api_key do
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Category Research Integration Test")
        IO.puts(String.duplicate("=", 80))

        category = "mechanical keyboards"

        coordinator_task = """
        Research the product category "#{category}" to find the best options.

        This is a CATEGORY research (not a specific product).

        Use AgentTool.call to delegate to these sub-agents:
        1. Legion.Test.ProductResearch.Agents.HackerNewsProductAgent - search for "#{category}" discussions
        2. Legion.Test.ProductResearch.Agents.RedditProductAgent - search in r/MechanicalKeyboards, r/hardware
        3. Legion.Test.ProductResearch.Agents.WebResearchAgent - find "best #{category}" reviews

        After gathering data, identify the most recommended products and provide:
        - top_recommendations: List of top 5 products, each with:
          - rank: 1-5
          - name: Product name
          - reason: Why it's recommended
          - pros: Key advantages
        - overall_summary: Overview of the category landscape

        Set research_type to "category" and product_or_category to "#{category}".
        """

        IO.puts("\n[1/2] Calling Coordinator Agent for category: #{category}")
        IO.puts("[2/2] Coordinator is delegating to sub-agents...\n")

        result = Legion.call(ProductCoordinatorAgent, coordinator_task, timeout: 300_000)

        assert match?({:ok, _}, result) or match?({:cancel, _}, result)

        {status, data} = result

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Category Research Results (#{status}):")
        IO.puts(String.duplicate("=", 80))

        if status == :ok do
          IO.puts("\nCategory: #{data["product_or_category"]}")
          IO.puts("Research Type: #{data["research_type"]}")
          IO.puts("Sources Consulted: #{data["sources_consulted"]}")

          IO.puts("\nTOP RECOMMENDATIONS:")
          Enum.each(data["top_recommendations"] || [], fn rec ->
            if is_map(rec) do
              IO.puts("\n  ##{rec["rank"] || "?"}: #{rec["name"] || "Unknown"}")
              IO.puts("     Reason: #{rec["reason"] || "N/A"}")
              pros = rec["pros"] || []
              pros_str = if is_list(pros), do: Enum.join(pros, ", "), else: inspect(pros)
              IO.puts("     Pros: #{pros_str}")
            else
              IO.puts("  * #{inspect(rec)}")
            end
          end)

          IO.puts("\nOVERALL SUMMARY:")
          IO.puts(data["overall_summary"])
        else
          IO.puts("\nCoordinator finished with status: #{status}")
          IO.puts(inspect(data, pretty: true))
        end

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Test completed!")
        IO.puts(String.duplicate("=", 80) <> "\n")

        assert true
      end
    end
  end
end
