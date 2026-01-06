defmodule Legion.Test.ProductResearch.Tools.HackerNewsProductTool do
  @moduledoc "Searches HackerNews for product posts and comments."
  use Legion.Tool

  @doc "Searches HackerNews posts. Returns list of maps with :title, :url, :score, :num_comments, :object_id."
  def search_product(product_name, limit \\ 15) do
    encoded_query = URI.encode(product_name)

    search_url =
      "https://hn.algolia.com/api/v1/search?query=#{encoded_query}&tags=story&hitsPerPage=#{limit}"

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

  @doc "Fetches comments from a HackerNews story. Returns list of comment text strings."
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
