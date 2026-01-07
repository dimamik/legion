defmodule Legion.Integration.ProductResearch.ProductResearchTest do
  @moduledoc """
  Multi-agent product research test.
  """
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.ProductResearch.Agents.ProductCoordinatorAgent

  @moduletag :integration
  @moduletag timeout: 300_000

  test "researches a product using multiple agents" do
    with_api_key do
      task =
        "Research dishwasher-safe silicone kitchen tongs. Give me top models with their pros and cons. Include source links to back up your findings."

      result = Legion.execute(ProductCoordinatorAgent, task, timeout: 300_000)

      assert {:ok, %{"response" => response}} = result

      # Verify the response contains product research results
      response_lower = String.downcase(response)
      assert response_lower =~ "tongs", "Response should mention tongs"

      # Check for structure indicating actual research was done
      # Should have either pros/cons sections, model names, or source links
      structure_indicators = ["pros", "cons", "model", "http"]
      has_structure = Enum.any?(structure_indicators, &(response_lower =~ &1))

      assert has_structure,
             "Response should contain meaningful product research with pros/cons, models, or source links"
    end
  end
end
