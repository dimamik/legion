defmodule Legion.Test.Support.MathAgent do
  @moduledoc """
  An agent that does math.
  """
  use Legion.Agent

  def tools, do: [Legion.Test.Support.MathTool]
end
