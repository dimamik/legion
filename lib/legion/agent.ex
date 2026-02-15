defmodule Legion.Agent do
  @moduledoc """
  `use Legion.Agent` to define your agent.

  ## Example

      defmodule MyAgent do
        @moduledoc "Researches topics and summarises findings."

        use Legion.Agent

        def tools, do: [MyApp.SearchTool, Legion.Tools.HumanTool]

        def tool_config(Legion.Tools.HumanTool), do: [handler: MyApp.ChatHandler, timeout: 30_000]

        def output_schema, do: %{"type" => "object", "properties" => %{"summary" => %{"type" => "string"}}}
      end

  ## Callbacks

  All callbacks are optional.

    - `tools/0` — list of tool modules available to the agent. Each tool's
      `tool_config/1` result is stored in the Vault under the tool's module key.
      Defaults to `[]`.

    - `tool_config/1` — per-tool configuration. Receives a tool module, returns a
      keyword list. The returned options are accessible to the tool at runtime via
      `Vault.get(__MODULE__)`. Defaults to `[]` for all tools.

    - `system_prompt/0` — the full system prompt sent to the LLM. Defaults to an
      auto-generated prompt built from `@moduledoc` and tool source code.

    - `output_schema/0` — JSON Schema map describing the agent's structured output.
      Used by the LLM for the `result` field. Defaults to `%{"type" => "string"}`.

    - `config/0` — agent-level configuration (model, max_iterations, etc.) merged
      with application config and call-time opts. Defaults to `%{}`.
  """

  @callback tools() :: [module()]
  @callback tool_config(tool :: atom()) :: keyword()
  @callback system_prompt() :: String.t()
  @callback output_schema() :: map()
  @callback config() :: map()
  @optional_callbacks tools: 0,
                      tool_config: 1,
                      system_prompt: 0,
                      output_schema: 0,
                      config: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour Legion.Agent
      @before_compile Legion.Agent

      def moduledoc do
        case @moduledoc do
          false -> raise "#{inspect(__MODULE__)} must define a @moduledoc"
          doc -> doc
        end
      end

      def tools, do: []
      def system_prompt, do: Legion.AgentPrompt.system_prompt(__MODULE__)
      def output_schema, do: %{"type" => "string"}
      def config, do: %{}

      defoverridable tools: 0, system_prompt: 0, output_schema: 0, config: 0
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def tool_config(_tool), do: []
    end
  end
end
