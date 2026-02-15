defmodule Legion.Test.Support.HackerNewsAgent do
  @moduledoc """
  An agent that fetches and summarizes HackerNews posts about a given topic.
  """
  use Legion.Agent

  def tools, do: [Legion.Test.Support.HackerNewsTool]
  def config, do: %{model: "openai:gpt-4o-mini"}
end
