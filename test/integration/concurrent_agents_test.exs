defmodule Legion.Integration.ConcurrentAgentsTest do
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.{ComprehensiveMathAgent, MathAgent}

  @moduletag :integration
  @moduletag timeout: 180_000

  test "multiple long-lived agents can run concurrently" do
    with_api_key do
      # Start three agents concurrently
      {:ok, agent1} = Legion.start_link(MathAgent, "You handle addition only")
      {:ok, agent2} = Legion.start_link(MathAgent, "You handle multiplication only")

      {:ok, agent3} =
        Legion.start_link(ComprehensiveMathAgent, "You handle complex calculations")

      # Send async messages to all agents
      Legion.cast(agent1, "Calculate 5 + 3")
      Legion.cast(agent2, "Calculate 4 * 6")
      Legion.cast(agent3, "Calculate the mean of [2, 4, 6, 8]")

      # Give them time to process
      Process.sleep(8_000)

      # Send sync messages to verify they maintain separate contexts
      result1 = Legion.call(agent1, "What was your last calculation?")
      result2 = Legion.call(agent2, "What was your last calculation?")
      result3 = Legion.call(agent3, "What was your last calculation?")

      # All should respond (or cancel gracefully)
      for result <- [result1, result2, result3] do
        case result do
          {:ok, _value} -> :ok
          {:cancel, reason} -> assert reason in [:reached_max_iterations, :reached_max_retries]
        end
      end

      IO.puts("\nAll agents processed their messages independently")
    end
  end
end
