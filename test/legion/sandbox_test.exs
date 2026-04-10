defmodule Legion.SandboxTest do
  use ExUnit.Case

  doctest Legion.Sandbox, import: true

  test "returns result and bindings" do
    assert {:ok, {5, bindings}} = Legion.Sandbox.execute("a = 2 + 2\na + 1", 15_000)
    assert Keyword.get(bindings, :a) == 4
  end

  test "accepts bindings from a previous execution" do
    {:ok, {_result, bindings}} = Legion.Sandbox.execute("posts = [1, 2, 3]", 15_000)
    assert {:ok, {6, _}} = Legion.Sandbox.execute("Enum.sum(posts)", 15_000, [], bindings)
  end

  test "bindings accumulate across calls" do
    {:ok, {_, b1}} = Legion.Sandbox.execute("x = 10", 15_000)
    {:ok, {_, b2}} = Legion.Sandbox.execute("y = 20", 15_000, [], b1)
    assert {:ok, {30, _}} = Legion.Sandbox.execute("x + y", 15_000, [], b2)
  end

  test "throw returns an error tuple instead of crashing" do
    assert {:error, {:throw, :foo}} = Legion.Sandbox.execute("throw(:foo)", 15_000)
  end

  test "exit returns an error tuple instead of crashing" do
    assert {:error, {:exit, :boom}} = Legion.Sandbox.execute("exit(:boom)", 15_000)
  end
end
