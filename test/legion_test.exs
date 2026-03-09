defmodule LegionTest do
  use ExUnit.Case
  doctest Legion

  test "start_link/2 returns a pid" do
    assert is_function(&Legion.start_link/2)
  end
end
