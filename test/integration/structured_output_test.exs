defmodule Legion.Integration.StructuredOutputTest do
  @moduledoc """
  Integration test: confirm custom output_schema works end-to-end with a real LLM.

  Skipped by default to avoid external API calls and LLM costs.
  Run with:

      mix test test/integration/structured_output_test.exs --include integration
  """
  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag timeout: 120_000

  defmodule SentimentAgent do
    @moduledoc "An agent that returns structured sentiment analysis."
    use Legion.Agent

    def output_schema do
      %{
        "type" => "object",
        "properties" => %{
          "sentiment" => %{"type" => "string", "enum" => ["positive", "negative", "neutral"]},
          "confidence" => %{"type" => "number"},
          "keywords" => %{"type" => "array", "items" => %{"type" => "string"}}
        },
        "required" => ["sentiment", "confidence", "keywords"]
      }
    end
  end

  setup do
    unless System.get_env("OPENAI_API_KEY"), do: raise("OPENAI_API_KEY not set")
    :ok
  end

  test "returns structured result matching custom output_schema" do
    assert {:ok, result} =
             Legion.execute(
               SentimentAgent,
               "Analyze the sentiment of: 'Elixir is a fantastic language!' " <>
                 "Return your analysis using the return action. Do not write code."
             )

    assert is_map(result)
    assert result["sentiment"] in ["positive", "negative", "neutral"]
    assert is_number(result["confidence"])
    assert is_list(result["keywords"])
  end
end
