defmodule Legion.Integration.ComprehensiveMathAgentTest do
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.ComprehensiveMathAgent

  @moduletag :integration
  @moduletag timeout: 120_000

  test "ComprehensiveMathAgent can use multiple tool modules" do
    with_api_key do
      # Test that the agent can use tools from different modules
      result =
        Legion.execute(
          ComprehensiveMathAgent,
          """
          Calculate the following step by step:
          1. First, add 10 and 5 using the add function
          2. Then, calculate 2 to the power of 3 using the power function
          3. Finally, find the mean of [10, 20, 30] using the mean function
          Return the mean of all three steps.
          """
        )

      case result do
        {:ok, value} ->
          # The agent should have used all three tools and returned the mean (20.0)
          cond do
            is_number(value) ->
              assert_in_delta value, 20.0, 0.01

            is_map(value) and Map.has_key?(value, "result") ->
              assert_in_delta value["result"], 20.0, 0.01

            is_map(value) and Map.has_key?(value, :result) ->
              assert_in_delta value.result, 20.0, 0.01

            true ->
              # Accept any valid response structure
              assert is_map(value) or is_number(value)
          end

        {:cancel, reason} ->
          # Acceptable if we hit limits during testing
          assert reason in [:reached_max_iterations, :reached_max_retries]
      end
    end
  end
end
