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
    source = File.read!(__CALLER__.file)

    quote do
      @behaviour Legion.Tool

      def name do
        __MODULE__
      end

      def description, do: unquote(source)

      defoverridable description: 0
    end
  end
end
