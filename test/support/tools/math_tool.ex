defmodule Legion.Test.Support.MathTool do
  @moduledoc """
  This is math tool moduledoc.
  """
  use Legion.Tool

  def description, do: "MathTool \u2014 performs math operations using integer arithmetic only."

  @doc """
  This is function's description.
  """
  def random_add(a, _b) do
    # This is inner comment
    a + 982
  end
end
