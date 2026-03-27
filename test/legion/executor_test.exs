defmodule Legion.ExecutorTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Legion.Test.Support.MathAgent

  defmodule ReturnOnlyAgent do
    @moduledoc "An agent restricted to return/done actions only."
    use Legion.Agent

    def action_types, do: ~w(return done)
  end

  setup :set_mimic_global

  @moduletag capture_log: true

  defp response(object) do
    {:ok, %ReqLLM.Response{id: "test", model: "test", context: nil, object: object}}
  end

  describe "action_types" do
    test "allows all four actions by default" do
      assert MathAgent.action_types() == ~w(eval_and_continue eval_and_complete return done)
    end

    test "restricted agent only allows return and done" do
      assert ReturnOnlyAgent.action_types() == ~w(return done)
    end

    test "disallowed action causes cancel after max_retries" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{"action" => "eval_and_continue", "code" => "1 + 1", "result" => ""})
      end)

      assert {:cancel, :reached_max_retries} =
               Legion.execute(ReturnOnlyAgent, "do something")
    end

    test "allowed action works on restricted agent" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{"action" => "return", "code" => "", "result" => "answer"})
      end)

      assert {:ok, "answer"} = Legion.execute(ReturnOnlyAgent, "do something")
    end
  end
end
