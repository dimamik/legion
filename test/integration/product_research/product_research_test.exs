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

      assert "tongs" in String.downcase(response)
    end
  end
end
