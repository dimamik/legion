defmodule Legion.Test.ProductResearch.Tools.RedditProductTool do
  @moduledoc "Searches Reddit for product posts and comments."
  use Legion.Tool

  @default_subreddits ["technology", "gadgets", "BuyItForLife", "ProductReviews"]

  @doc "Searches Reddit. Returns list of maps with :title, :url, :score, :selftext, :subreddit, :permalink."
  def search_product(product_name, subreddits \\ @default_subreddits, limit \\ 15) do
    encoded_query = URI.encode(product_name)
    subreddit_str = Enum.join(subreddits, "+")

    search_url =
      "https://www.reddit.com/r/#{subreddit_str}/search.json?q=#{encoded_query}&restrict_sr=1&limit=100&sort=relevance"

    headers = [{"User-Agent", "Legion Product Research Bot 1.0"}]

    case Req.get(search_url, headers: headers) do
      {:ok, %{status: 200, body: %{"data" => %{"children" => posts}}}} ->
        posts
        |> Enum.take(limit)
        |> Enum.map(fn %{"data" => post} ->
          %{
            title: Map.get(post, "title", ""),
            url: Map.get(post, "url", ""),
            score: Map.get(post, "score", 0),
            selftext: Map.get(post, "selftext", ""),
            subreddit: Map.get(post, "subreddit", ""),
            num_comments: Map.get(post, "num_comments", 0),
            permalink: Map.get(post, "permalink", ""),
            source: "Reddit"
          }
        end)

      _ ->
        []
    end
  end

  @doc "Fetches comments from a Reddit post. Returns list of comment text strings."
  def fetch_comments(permalink, limit \\ 25) do
    # Clean up permalink and construct URL
    clean_permalink = String.trim_leading(permalink, "/")
    comments_url = "https://www.reddit.com/#{clean_permalink}.json?limit=#{limit}&depth=1"

    headers = [{"User-Agent", "Legion Product Research Bot 1.0"}]

    case Req.get(comments_url, headers: headers) do
      {:ok, %{status: 200, body: [_post, %{"data" => %{"children" => comments}}]}} ->
        comments
        |> Enum.take(limit)
        |> Enum.map(&extract_comment_text/1)
        |> Enum.filter(&(&1 != nil))
        |> Enum.take(limit)

      _ ->
        []
    end
  end

  defp extract_comment_text(%{"data" => data}) do
    body = data["body"] || ""

    if String.length(body) > 0 and body != "[deleted]" and body != "[removed]" do
      body
    else
      nil
    end
  end

  defp extract_comment_text(_), do: nil
end
