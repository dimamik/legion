defmodule Legion.SandboxTest do
  use ExUnit.Case

  doctest Legion.Sandbox, import: true

  test "happy path works" do
    code = """
    a = 2 + 2
    a + 1
    """

    assert {:ok, 5} = Legion.Sandbox.execute(code)
  end
end
