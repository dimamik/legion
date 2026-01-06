defmodule Legion.Test.ProductResearch.Tools.HackerNewsProductTool do
  @moduledoc """
  Tool for searching HackerNews for product-related posts and comments.
  Uses the Algolia search API and Firebase API for data fetching.
  """
  use Legion.Tool

  @doc """
  Searches HackerNews for posts mentioning the given product name.
  Uses the Algolia search API for efficient full-text search.

  ## Parameters
    - product_name: The name of the product to search for
    - limit: Maximum number of posts to return (default: 15)

  ## Returns
  A list of maps with :title, :url, :score, :text, :num_comments, :object_id, and :source fields.
  """
  def search_product(product_name, limit \\ 15) do
    encoded_query = URI.encode(product_name)
    search_url = "https://hn.algolia.com/api/v1/search?query=#{encoded_query}&tags=story&hitsPerPage=#{limit}"

    case Req.get(search_url) do
      {:ok, %{status: 200, body: %{"hits" => hits}}} ->
        hits
        |> Enum.take(limit)
        |> Enum.map(fn hit ->
          %{
            title: hit["title"] || "",
            url: hit["url"] || "",
            score: hit["points"] || 0,
            text: hit["story_text"] || "",
            num_comments: hit["num_comments"] || 0,
            object_id: hit["objectID"] || "",
            source: "HackerNews"
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Fetches comments from a HackerNews story.

  ## Parameters
    - item_id: The HackerNews item ID (objectID from search results)
    - limit: Maximum number of comments to return (default: 25)

  ## Returns
  A list of comment text strings.
  """
  def fetch_comments(item_id, limit \\ 25) do
    item_url = "https://hacker-news.firebaseio.com/v0/item/#{item_id}.json"

    case Req.get(item_url) do
      {:ok, %{status: 200, body: item}} when is_map(item) ->
        kids = item["kids"] || []

        kids
        |> Enum.take(limit)
        |> Enum.map(&fetch_comment_text/1)
        |> Enum.filter(&(&1 != nil))
        |> Enum.take(limit)

      _ ->
        []
    end
  end

  defp fetch_comment_text(comment_id) do
    comment_url = "https://hacker-news.firebaseio.com/v0/item/#{comment_id}.json"

    case Req.get(comment_url) do
      {:ok, %{status: 200, body: comment}} when is_map(comment) ->
        text = comment["text"] || ""
        if String.length(text) > 0, do: text, else: nil

      _ ->
        nil
    end
  end
end
