defmodule Legion.Test.Support.RedditAgent do
  @moduledoc """
  An agent that fetches and summarizes Reddit posts about a given topic.
  """
  use Legion.Agent

  def tools, do: [Legion.Test.Support.RedditTool]
  def config, do: %{model: "openai:gpt-4o-mini"}
end
