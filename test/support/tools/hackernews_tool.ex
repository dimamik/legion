defmodule Legion.Test.Support.HackerNewsTool do
  @moduledoc """
  Tool for fetching posts from HackerNews API.
  """
  use Legion.Tool

  @doc """
  Fetches posts from HackerNews that contain the given search term.

  ## Parameters
    - term: The search term to filter posts by (case-insensitive)
    - limit: Maximum number of matching posts to return (default: 10)

  ## Returns
  A list of maps with :title, :url, :score, :text, and :source fields.
  """
  def fetch_posts(term, limit \\ 10) do
    case Req.get("https://hacker-news.firebaseio.com/v0/topstories.json") do
      {:ok, %{status: 200, body: story_ids}} ->
        term_pattern = term |> String.downcase() |> Regex.escape()

        story_ids
        |> Enum.take(100)
        |> Enum.map(&fetch_story/1)
        |> Enum.filter(fn story -> story != nil and matches_term?(story, term_pattern) end)
        |> Enum.take(limit)

      _ ->
        []
    end
  end

  @doc """
  Extracts key sentiment words from text.
  Returns a map with :positive and :negative word lists.
  """
  def extract_sentiment(text) do
    positive_words = ["great", "love", "awesome", "excellent", "amazing", "best", "good"]
    negative_words = ["bad", "hate", "terrible", "awful", "worst", "difficult", "problem"]
    text_lower = String.downcase(text)

    %{
      positive: Enum.filter(positive_words, &String.contains?(text_lower, &1)),
      negative: Enum.filter(negative_words, &String.contains?(text_lower, &1))
    }
  end

  defp fetch_story(story_id) do
    case Req.get("https://hacker-news.firebaseio.com/v0/item/#{story_id}.json") do
      {:ok, %{status: 200, body: story}} when is_map(story) ->
        %{
          title: story["title"] || "",
          url: story["url"] || "",
          score: story["score"] || 0,
          text: story["text"] || "",
          source: "HackerNews"
        }

      _ ->
        nil
    end
  end

  defp matches_term?(%{title: title, text: text}, term_pattern) do
    String.match?("#{title} #{text}" |> String.downcase(), ~r/#{term_pattern}/i)
  end
end
