defmodule Legion.Integration.ProductResearch.ProductResearchTest do
  @moduledoc """
  Multi-agent product research test. Run with: --include product_research
  """
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent

  @moduletag :integration
  @moduletag timeout: 300_000
  @moduletag :product_research

  test "researches a product using multiple agents" do
    with_api_key do
      task =
        "Research 'Sony WH-1000XM5' headphones. Find pros, cons, and alternatives. Include source links to back up your findings."

      result = Legion.call(ProductCoordinatorAgent, task, timeout: 300_000)

      assert {:ok, %{"response" => response}} = result
      IO.inspect(response)
    end
  end
end
