defmodule Legion.SandboxTest do
  use ExUnit.Case, async: true

  alias Legion.Sandbox

  describe "eval/3" do
    test "evaluates simple expressions" do
      assert {:ok, 3} = Sandbox.eval("1 + 2", Legion.Sandbox.DefaultAllowlist)
    end

    test "evaluates complex expressions" do
      code = """
      [1, 2, 3, 4, 5]
      |> Enum.map(&(&1 * 2))
      |> Enum.sum()
      """

      assert {:ok, 30} = Sandbox.eval(code, Legion.Sandbox.DefaultAllowlist)
    end

    test "returns error for runtime exceptions" do
      assert {:error, %{type: :exception}} =
               Sandbox.eval("1 / 0", Legion.Sandbox.DefaultAllowlist)
    end

    test "allows standard library functions" do
      assert {:ok, "hello world"} =
               Sandbox.eval(~s|String.downcase("HELLO WORLD")|, Legion.Sandbox.DefaultAllowlist)
    end

    test "allows Enum functions" do
      assert {:ok, [2, 4, 6]} =
               Sandbox.eval("Enum.map([1, 2, 3], &(&1 * 2))", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts dangerous functions" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("File.cwd!()", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts spawn" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("spawn(fn -> :ok end)", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts send" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("send(self(), :msg)", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts receive" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("receive do x -> x end", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts apply" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("apply(File, :cwd!, [])", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts Code.eval_string" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval(~s|Code.eval_string("1 + 1")|, Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts System module" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("System.cmd(\"ls\", [])", Legion.Sandbox.DefaultAllowlist)
    end

    test "restricts defmodule" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("defmodule Foo do end", Legion.Sandbox.DefaultAllowlist)
    end

    test "times out on infinite loops" do
      assert {:error, %{type: :timeout}} =
               Sandbox.eval(
                 "loop = fn f -> f.(f) end; loop.(loop)",
                 Legion.Sandbox.DefaultAllowlist,
                 timeout: 100
               )
    end

    test "returns parsing errors" do
      assert {:error, %{type: :parsing}} =
               Sandbox.eval("def foo(", Legion.Sandbox.DefaultAllowlist)
    end
  end

  describe "eval/3 with custom allowlist" do
    defmodule TestMathTool do
      use Legion.Tool

      def add(a, b), do: a + b
      def multiply(a, b), do: a * b
    end

    defmodule TestAllowlist do
      use Legion.Sandbox.Allowlist, extend: Legion.Sandbox.DefaultAllowlist
      allow(Legion.SandboxTest.TestMathTool, :all)
    end

    test "allows tool module calls with custom allowlist" do
      assert {:ok, 7} =
               Sandbox.eval(
                 "Legion.SandboxTest.TestMathTool.add(3, 4)",
                 TestAllowlist
               )
    end

    test "restricts tool module calls without proper allowlist" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval(
                 "Legion.SandboxTest.TestMathTool.add(3, 4)",
                 Legion.Sandbox.DefaultAllowlist
               )
    end
  end

  describe "eval/3 with function captures" do
    test "allows captures of allowed functions" do
      # Test capture of Enum function
      assert {:ok, 6} =
               Sandbox.eval(
                 "(&Enum.sum/1).([1, 2, 3])",
                 Legion.Sandbox.DefaultAllowlist
               )

      # Test capture of String function
      assert {:ok, "HELLO"} =
               Sandbox.eval(
                 "(&String.upcase/1).(\"hello\")",
                 Legion.Sandbox.DefaultAllowlist
               )
    end

    test "restricts captures of forbidden functions" do
      assert {:error, %{type: :restricted}} =
               Sandbox.eval("&File.read/1", Legion.Sandbox.DefaultAllowlist)
    end
  end
end
