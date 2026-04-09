defmodule Legion.Tool do
  @moduledoc """
  `use Legion.Tool` to mark a module as a tool available to agents.

  By default, `description/0` returns the module's source code so the LLM
  knows what functions are available.

  ## Overridable

    - `description/0` — override to return a hand-written summary **instead of**
      the source code. Defaults to the module's source code.

  ## Example

      defmodule MyApp.WeatherTool do
        use Legion.Tool

        def description do
          \"""
          WeatherTool — fetches current weather data.

          ## Functions
          - `current(city)` — returns weather JSON for the given city name.
          \"""
        end

        @doc "Returns current weather for a city."
        def current(city) do
          Req.get!("https://wttr.in/\#{city}?format=j1").body
        end
      end
  """

  @callback description() :: String.t()

  defmacro __using__(_opts) do
    source = extract_module_source(File.read!(__CALLER__.file), __CALLER__.module)

    quote do
      @behaviour Legion.Tool

      def description, do: unquote(source)

      defoverridable description: 0
    end
  end

  # NOTE: returns the whole file for nested modules
  @doc false
  def extract_module_source(code, module) do
    module_header = "defmodule #{inspect(module)} do"
    lines = String.split(code, "\n")

    case Enum.find_index(lines, &String.contains?(&1, module_header)) do
      nil ->
        raise "Could not find #{module_header} in source file"

      start_idx ->
        lines
        |> Enum.drop(start_idx)
        |> extract_do_end_block()
        |> Enum.join("\n")
    end
  end

  defp extract_do_end_block(lines) do
    Enum.reduce_while(lines, {[], 0}, fn line, {acc, depth} ->
      depth = depth + count_opens(line) - count_closes(line)

      if depth == 0 and acc != [] do
        {:halt, {Enum.reverse([line | acc]), depth}}
      else
        {:cont, {[line | acc], depth}}
      end
    end)
    |> elem(0)
  end

  defp count_opens(line) do
    line = strip_strings_and_comments(line)
    dos = length(Regex.scan(~r/\bdo\s*$/, line))
    fns = length(Regex.scan(~r/\bfn\b/, line))
    dos + fns
  end

  defp count_closes(line) do
    line = strip_strings_and_comments(line)
    length(Regex.scan(~r/\bend\b/, line))
  end

  defp strip_strings_and_comments(line) do
    line
    |> String.replace(~r/#.*$/, "")
    |> String.replace(~r/"(?:[^"\\]|\\.)*"/, "")
  end
end
