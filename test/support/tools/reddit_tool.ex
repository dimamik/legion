defmodule Legion.Test.Support.RedditTool do
  @moduledoc """
  Tool for fetching posts from Reddit API.
  """
  use Legion.Tool

  @doc """
  Fetches posts from a subreddit that contain the given search term.

  ## Parameters
    - term: The search term to filter posts by (case-insensitive)
    - subreddit: The subreddit to search (default: "programming")
    - limit: Maximum number of matching posts to return (default: 10)

  ## Returns
  A list of maps with :title, :url, :score, :selftext, and :source fields.
  """
  def fetch_posts(term, subreddit \\ "programming", limit \\ 10) do
    url = "https://www.reddit.com/r/#{subreddit}/hot.json?limit=100"

    case Req.get(url, headers: [{"User-Agent", "Legion Test Bot 1.0"}]) do
      {:ok, %{status: 200, body: %{"data" => %{"children" => posts}}}} ->
        term_pattern = term |> String.downcase() |> Regex.escape()

        posts
        |> Enum.map(fn %{"data" => post} ->
          %{
            title: post["title"] || "",
            url: post["url"] || "",
            score: post["score"] || 0,
            selftext: post["selftext"] || "",
            source: "Reddit r/#{subreddit}"
          }
        end)
        |> Enum.filter(&matches_term?(&1, term_pattern))
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

  defp matches_term?(%{title: title, selftext: selftext}, term_pattern) do
    String.match?("#{title} #{selftext}" |> String.downcase(), ~r/#{term_pattern}/i)
  end
end
