defmodule LegionTest do
  use ExUnit.Case

  # Reference test agent and tool modules
  alias Legion.Test.{AdvancedMathTool, ComprehensiveMathAgent, MathAgent, MathTool, StatsTool}

  describe "Tool introspection" do
    test "MathTool exposes function info via __tool_info__" do
      info = MathTool.__tool_info__()

      assert info.module == MathTool
      assert info.moduledoc =~ "arithmetic operations"

      function_names = Enum.map(info.functions, & &1.name)
      assert :add in function_names
      assert :subtract in function_names
      assert :multiply in function_names
      assert :divide in function_names
    end

    test "AdvancedMathTool exposes function docs" do
      info = AdvancedMathTool.__tool_info__()

      power_fn = Enum.find(info.functions, &(&1.name == :power))
      assert power_fn.doc =~ "power"
      assert power_fn.arity == 2
    end
  end

  describe "AIAgent introspection" do
    test "MathAgent exposes agent info" do
      info = MathAgent.__legion_agent_info__()

      assert info.module == MathAgent
      assert info.moduledoc =~ "mathematical calculations"
      assert MathTool in info.tools
      assert AdvancedMathTool in info.tools
    end

    test "MathAgent has output schema" do
      schema = MathAgent.output_schema()

      assert is_list(schema)
      assert Keyword.has_key?(schema, :result)
      assert Keyword.has_key?(schema, :explanation)
    end
  end

  describe "Prompt building" do
    test "builds system prompt with tool documentation" do
      prompt = Legion.LLM.PromptBuilder.build_system_prompt(MathAgent)

      # Should include agent description
      assert prompt =~ "mathematical calculations"

      # Should include tool modules
      assert prompt =~ "MathTool"
      assert prompt =~ "AdvancedMathTool"

      # Should include function docs
      assert prompt =~ "add"
      assert prompt =~ "multiply"
      assert prompt =~ "power"
      assert prompt =~ "factorial"

      assert prompt =~ "You are an AI agent that accomplishes tasks by writing Elixir code"
    end
  end

  describe "Sandbox eval" do
    test "can eval math tool functions using agent as allowlist" do
      # MathAgent itself implements Legion.Sandbox.Allowlist and allows its tools
      assert {:ok, 7} =
               Legion.Sandbox.eval(
                 "Legion.Test.MathTool.add(3, 4)",
                 MathAgent
               )

      assert {:ok, 8.0} =
               Legion.Sandbox.eval(
                 "Legion.Test.AdvancedMathTool.power(2, 3)",
                 MathAgent
               )
    end
  end

  describe "StatsTool introspection" do
    test "StatsTool exposes function info via __tool_info__" do
      info = StatsTool.__tool_info__()

      assert info.module == StatsTool
      assert info.moduledoc =~ "Statistical operations"

      function_names = Enum.map(info.functions, & &1.name)
      assert :mean in function_names
      assert :sum in function_names
      assert :min in function_names
      assert :max in function_names
    end
  end

  describe "ComprehensiveMathAgent introspection" do
    test "ComprehensiveMathAgent has all three tool modules" do
      info = ComprehensiveMathAgent.__legion_agent_info__()

      assert MathTool in info.tools
      assert AdvancedMathTool in info.tools
      assert StatsTool in info.tools
    end

    test "ComprehensiveMathAgent has custom config" do
      config = ComprehensiveMathAgent.config()

      assert config.max_iterations == 15
      assert config.max_retries == 3
    end
  end

  describe "Sandbox eval with multiple tool modules" do
    test "can eval all three math tools using ComprehensiveMathAgent as allowlist" do
      # ComprehensiveMathAgent has all three tools and implements Legion.Sandbox.Allowlist
      assert {:ok, 7} =
               Legion.Sandbox.eval(
                 "Legion.Test.MathTool.add(3, 4)",
                 ComprehensiveMathAgent
               )

      assert {:ok, 8.0} =
               Legion.Sandbox.eval(
                 "Legion.Test.AdvancedMathTool.power(2, 3)",
                 ComprehensiveMathAgent
               )

      assert {:ok, 20.0} =
               Legion.Sandbox.eval(
                 "Legion.Test.StatsTool.mean([10, 20, 30])",
                 ComprehensiveMathAgent
               )
    end
  end
end
