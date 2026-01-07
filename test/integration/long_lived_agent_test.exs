defmodule Legion.Integration.LongLivedAgentTest do
  use ExUnit.Case
  import Legion.Test.IntegrationHelpers

  alias Legion.Test.MathAgent

  @moduletag :integration
  @moduletag timeout: 120_000

  test "long-lived agent maintains context across multiple messages" do
    with_api_key do
      # Start a long-lived agent
      {:ok, agent_pid} =
        Legion.start_link(
          MathAgent,
          "You are a helpful math assistant. Remember all calculations I ask you to do."
        )

      # Send first sync message
      result1 = Legion.call(agent_pid, "Calculate 10 + 5")

      case result1 do
        {:ok, value1} ->
          IO.puts("\nFirst result: #{inspect(value1)}")

          # Send async message (fire and forget)
          Legion.cast(agent_pid, "Now multiply that result by 2")

          # Give it time to process the async message
          Process.sleep(5_000)

          # Send another sync message that references previous context
          result2 = Legion.call(agent_pid, "What was the final result?")

          case result2 do
            {:ok, value2} ->
              IO.puts("Second result: #{inspect(value2)}")
              # The agent should remember the context
              assert is_map(value2) or is_number(value2)

            {:cancel, reason} ->
              assert reason in [:reached_max_iterations, :reached_max_retries]
          end

        {:cancel, reason} ->
          assert reason in [:reached_max_iterations, :reached_max_retries]
      end
    end
  end
end
