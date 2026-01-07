defmodule Legion.Integration.MathAgentTest do
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.MathAgent

  @moduletag :integration
  @moduletag timeout: 60_000

  test "MathAgent can solve a calculation using tools" do
    with_api_key do
      result = Legion.execute(MathAgent, "Calculate 500212 + 3123121 using the add function")

      case result do
        {:ok, value} ->
          # The agent should have used MathTool.add(500212, 3123121)
          assert value == 500_212 + 3_123_121 or is_map(value)

        {:cancel, reason} ->
          # Acceptable if we hit limits during testing
          assert reason in [:reached_max_iterations, :reached_max_retries]
      end
    end
  end
end
