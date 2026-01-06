defmodule Legion.Test.ProductResearch.Tools.RedditProductTool do
  @moduledoc """
  Tool for searching Reddit for product-related posts and comments.
  Uses Reddit's JSON API for data fetching.
  """
  use Legion.Tool

  @default_subreddits ["technology", "gadgets", "BuyItForLife", "ProductReviews"]

  @doc """
  Searches Reddit for posts mentioning the given product name.

  ## Parameters
    - product_name: The name of the product to search for
    - subreddits: List of subreddits to search (default: ["technology", "gadgets", "BuyItForLife", "ProductReviews"])
    - limit: Maximum number of posts to return (default: 15)

  ## Returns
  A list of maps with :title, :url, :score, :selftext, :subreddit, :num_comments, :permalink, and :source fields.

  ## Examples

      search_product("Sony headphones")
      search_product("Sony headphones", ["headphones", "audiophile"])
      search_product("Sony headphones", ["headphones", "audiophile"], 25)
  """
  def search_product(product_name, subreddits \\ @default_subreddits, limit \\ 15) do
    encoded_query = URI.encode(product_name)
    subreddit_str = Enum.join(subreddits, "+")
    search_url = "https://www.reddit.com/r/#{subreddit_str}/search.json?q=#{encoded_query}&restrict_sr=1&limit=100&sort=relevance"

    headers = [{"User-Agent", "Legion Product Research Bot 1.0"}]

    case Req.get(search_url, headers: headers) do
      {:ok, %{status: 200, body: %{"data" => %{"children" => posts}}}} ->
        posts
        |> Enum.take(limit)
        |> Enum.map(fn %{"data" => post} ->
          %{
            title: post["title"] || "",
            url: post["url"] || "",
            score: post["score"] || 0,
            selftext: post["selftext"] || "",
            subreddit: post["subreddit"] || "",
            num_comments: post["num_comments"] || 0,
            permalink: post["permalink"] || "",
            source: "Reddit"
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Fetches comments from a Reddit post.

  ## Parameters
    - permalink: The Reddit post permalink (e.g., "/r/technology/comments/abc123/title/")
    - limit: Maximum number of comments to return (default: 25)

  ## Returns
  A list of comment text strings.
  """
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
