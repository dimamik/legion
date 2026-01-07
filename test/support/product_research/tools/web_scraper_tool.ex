defmodule Legion.Test.ProductResearch.Tools.WebScraperTool do
  @moduledoc "Web scraping using DuckDuckGo search."
  use Legion.Tool

  @doc "Fetches page content. Returns map with :url, :title, :text_content, :status."
  def fetch_page(url) do
    headers = [
      {"User-Agent", "Mozilla/5.0 (compatible; Legion Research Bot 1.0)"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}
    ]

    case Req.get(url, headers: headers, max_redirects: 3) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        %{
          url: url,
          title: extract_title(body),
          text_content: extract_text_content(body),
          status: 200
        }

      {:ok, %{status: status}} ->
        %{error: "HTTP #{status}", url: url}

      {:error, reason} ->
        %{error: inspect(reason), url: url}
    end
  end

  @doc "Searches with DuckDuckGo. Returns list of maps with :title, :url, :snippet."
  def search_web(query, limit \\ 10) do
    encoded_query = URI.encode(query)
    search_url = "https://html.duckduckgo.com/html/?q=#{encoded_query}"

    headers = [
      {"User-Agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.5"}
    ]

    case Req.get(search_url, headers: headers) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        parse_duckduckgo_results(body, limit)

      _ ->
        []
    end
  end

  defp extract_title(html) do
    case Regex.run(~r/<title[^>]*>([^<]+)<\/title>/i, html) do
      [_, title] -> String.trim(title)
      _ -> ""
    end
  end

  defp extract_text_content(html) do
    html
    # Remove script and style tags with their content
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, " ")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/is, " ")
    # Remove HTML comments
    |> String.replace(~r/<!--.*?-->/s, " ")
    # Remove all HTML tags
    |> String.replace(~r/<[^>]+>/, " ")
    # Decode common HTML entities
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    # Normalize whitespace
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    # Limit length to avoid overwhelming the agent
    |> String.slice(0, 10_000)
  end

  defp parse_duckduckgo_results(html, limit) do
    # DuckDuckGo HTML results are in <a class="result__a" href="...">Title</a> tags
    # Note: class comes BEFORE href in the HTML
    result_pattern = ~r/<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>([^<]+)<\/a>/i
    snippet_pattern = ~r/<a[^>]+class="result__snippet"[^>]*>([^<]+)/i

    links = Regex.scan(result_pattern, html)
    snippets = Regex.scan(snippet_pattern, html)

    # Pad snippets list to match links length
    padded_snippets =
      snippets ++ List.duplicate(["", ""], max(0, length(links) - length(snippets)))

    links
    |> Enum.zip(padded_snippets)
    |> Enum.take(limit)
    |> Enum.map(fn {[_, url, title], snippet_match} ->
      snippet =
        case snippet_match do
          [_, text] -> String.trim(text)
          _ -> ""
        end

      # DuckDuckGo uses redirect URLs, extract actual URL from uddg param
      # URL is HTML-encoded, so decode &amp; to &
      clean_url = String.replace(url, "&amp;", "&")
      actual_url = extract_actual_url(clean_url)

      %{
        title: String.trim(title),
        url: actual_url,
        snippet: snippet
      }
    end)
    |> Enum.filter(fn result -> result.url != "" and result.title != "" end)
  end

  defp extract_actual_url(url) do
    # DuckDuckGo redirects through //duckduckgo.com/l/?uddg=<encoded_url>
    case Regex.run(~r/uddg=([^&]+)/, url) do
      [_, encoded] -> URI.decode(encoded)
      _ -> url
    end
  end
end
