defmodule Legion.ExecutorTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Legion.Test.Support.MathAgent

  defmodule ReturnOnlyAgent do
    @moduledoc "An agent restricted to return/done actions only."
    use Legion.Agent

    def action_types, do: ~w(return done)
  end

  defmodule StructuredOutputAgent do
    @moduledoc "An agent with a custom output schema."
    use Legion.Agent

    def output_schema do
      %{
        "type" => "object",
        "properties" => %{
          "summary" => %{"type" => "string"},
          "score" => %{"type" => "integer"}
        },
        "required" => ["summary", "score"]
      }
    end
  end

  setup :set_mimic_global

  @moduletag capture_log: true

  defp response(object) do
    {:ok, %ReqLLM.Response{id: "test", model: "test", context: nil, object: object}}
  end

  describe "run/4" do
    test "returns result for return action" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{"action" => "return", "code" => "", "result" => "42"})
      end)

      assert {:ok, "42"} = Legion.execute(MathAgent, "what is 42?")
    end

    test "returns nil for done action" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{"action" => "done", "code" => "", "result" => ""})
      end)

      assert {:ok, nil} = Legion.execute(MathAgent, "nothing")
    end

    test "eval_and_complete executes code and returns result" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{"action" => "eval_and_complete", "code" => "1 + 1", "result" => ""})
      end)

      assert {:ok, 2} = Legion.execute(MathAgent, "add")
    end

    test "eval_and_continue chains into next iteration" do
      call_count = :counters.new(1, [:atomics])

      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        :counters.add(call_count, 1, 1)

        case :counters.get(call_count, 1) do
          1 -> response(%{"action" => "eval_and_continue", "code" => "x = 10", "result" => ""})
          2 -> response(%{"action" => "eval_and_complete", "code" => "x * 2", "result" => ""})
        end
      end)

      assert {:ok, 20} = Legion.execute(MathAgent, "compute")
    end

    test "cancels after max_iterations" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{"action" => "eval_and_continue", "code" => "1", "result" => ""})
      end)

      assert {:cancel, :reached_max_iterations} =
               Legion.execute(MathAgent, "loop forever")
    end

    test "retries on code execution error and cancels after max_retries" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{
          "action" => "eval_and_complete",
          "code" => "raise \"boom\"",
          "result" => ""
        })
      end)

      assert {:cancel, :reached_max_retries} = Legion.execute(MathAgent, "fail")
    end

    test "LLM error triggers retry" do
      call_count = :counters.new(1, [:atomics])

      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        :counters.add(call_count, 1, 1)

        case :counters.get(call_count, 1) do
          1 -> {:error, "connection refused"}
          2 -> response(%{"action" => "return", "code" => "", "result" => "recovered"})
        end
      end)

      assert {:ok, "recovered"} = Legion.execute(MathAgent, "retry me")
    end

    test "missing action field in LLM response triggers retry" do
      call_count = :counters.new(1, [:atomics])

      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        :counters.add(call_count, 1, 1)

        case :counters.get(call_count, 1) do
          1 -> response(%{"code" => "1 + 1", "result" => ""})
          2 -> response(%{"action" => "return", "code" => "", "result" => "ok"})
        end
      end)

      assert {:ok, "ok"} = Legion.execute(MathAgent, "recover")
    end
  end

  describe "result formatting" do
    test "available variables are listed in the result message" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)
      test_pid = self()

      stub(ReqLLM, :generate_object, fn _m, messages, _s ->
        i = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

        if i > 0 do
          last_msg = messages |> List.last() |> Map.get(:content)
          send(test_pid, {:result_msg, last_msg})
        end

        case i do
          0 ->
            response(%{
              "action" => "eval_and_continue",
              "code" => "posts = [1, 2]",
              "result" => ""
            })

          1 ->
            response(%{"action" => "return", "code" => "", "result" => "done"})
        end
      end)

      assert {:ok, "done"} = Legion.execute(MathAgent, "test var listing")

      assert_received {:result_msg, msg}
      assert msg =~ "Available variables:"
      assert msg =~ "`posts`"
    end
  end

  describe "custom output_schema" do
    test "schema is passed to LLM with additionalProperties injected" do
      test_pid = self()

      stub(ReqLLM, :generate_object, fn _model, _messages, schema ->
        send(test_pid, {:schema, schema})

        response(%{
          "action" => "return",
          "code" => "",
          "result" => %{"summary" => "hi", "score" => 1}
        })
      end)

      Legion.execute(StructuredOutputAgent, "test")

      assert_received {:schema, schema}
      result_schema = schema["properties"]["result"]
      assert result_schema["additionalProperties"] == false
      assert result_schema["properties"] == StructuredOutputAgent.output_schema()["properties"]
    end

    test "return action passes structured result through" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{
          "action" => "return",
          "code" => "",
          "result" => %{"summary" => "all good", "score" => 95}
        })
      end)

      assert {:ok, %{"summary" => "all good", "score" => 95}} =
               Legion.execute(StructuredOutputAgent, "evaluate")
    end

    test "eval_and_complete returns code result, not the schema result field" do
      stub(ReqLLM, :generate_object, fn _model, _messages, _schema ->
        response(%{
          "action" => "eval_and_complete",
          "code" => "%{summary: \"computed\", score: 42}",
          "result" => ""
        })
      end)

      assert {:ok, %{summary: "computed", score: 42}} =
               Legion.execute(StructuredOutputAgent, "compute")
    end
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
