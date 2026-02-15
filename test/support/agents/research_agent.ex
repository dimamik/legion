defmodule Legion.Test.Support.ResearchAgent do
  @moduledoc """
  An agent that researches a topic across HackerNews and Reddit.

  Given a search term, it fetches posts from both platforms, analyzes sentiment,
  and returns a summary of what people are saying about the topic.
  """
  use Legion.Agent

  def tools, do: [Legion.Test.Support.HackerNewsTool, Legion.Test.Support.RedditTool]
  def config, do: %{model: "openai:gpt-4o-mini"}
end
