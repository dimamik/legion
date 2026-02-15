# Legion

> [!WARNING]
> Early stages of development. Expect breaking changes.

<!-- MDOC -->

Legion is an Elixir framework for building AI agents that solve tasks by writing and executing Elixir code.

Traditional agent frameworks give the LLM a list of function signatures and execute them one at a time, one round-trip per call. Legion gives the LLM the **source code** of your tools and lets it write Elixir that composes them - calling multiple tools, filtering results, chaining pipes - all in a single execution step.

```elixir
# The LLM writes this. Legion executes it in a sandbox.
ScraperTool.fetch_posts()
|> Enum.filter(& String.contains?(String.downcase(&1["title"]), "elixir"))
|> Enum.map(& DatabaseTool.insert_post(&1["title"]))
```

## Why

- **Tools are just modules.** Add `use Legion.Tool` to any module - yours or third-party. Every public function becomes available to the agent.
- **Multiple tool calls per step.** The LLM writes real Elixir - pipes, filters, pattern matching - composing as many tool calls as it needs in one execution, not one round-trip per function.
- **Sandboxed.** AST-level validation before execution. Only allowed modules can be called. Configurable timeouts. No file I/O, no spawning, no escape.
- **~1100 lines total.** The entire framework.

## Quick Start

Define a tool, define an agent, run it:

```elixir
defmodule MyApp.ScraperTool do
  use Legion.Tool

  @doc "Fetches recent posts from HackerNews"
  def fetch_posts do
    Req.get!("https://hn.algolia.com/api/v1/search_by_date").body["hits"]
  end
end

defmodule MyApp.ResearchAgent do
  @moduledoc "Finds and evaluates HackerNews posts."
  use Legion.Agent

  def tools, do: [MyApp.ScraperTool]
end

{:ok, result} = Legion.execute(MyApp.ResearchAgent, "Find cool Elixir posts about Advent of Code")
```

## How It Works

1. The LLM receives the task + **source code** of available tools.
2. It responds with an action: execute code, return a result, or signal done.
3. Legion validates the AST, runs the code in a sandboxed process, feeds the result back.
4. Loop until done (or iteration/retry limits hit).

## Installation

```elixir
def deps do
  [{:legion, "~> 0.1"}]
end
```

```elixir
# config/runtime.exs
config :req_llm, openai_api_key: System.get_env("OPENAI_API_KEY")
```

See [req_llm docs](https://hexdocs.pm/req_llm/ReqLLM.html#module-configuration) for all LLM providers.

## Long-lived Agents

```elixir
{:ok, pid} = Legion.start_link(MyApp.AssistantAgent)
{:ok, response} = Legion.call(pid, "Analyze this data")
{:ok, followup} = Legion.call(pid, "Now filter for items over $100")
```

## Multi-Agent Systems

Agents can delegate to other agents:

```elixir
defmodule MyApp.OrchestratorAgent do
  @moduledoc "Coordinates research across multiple sources."
  use Legion.Agent

  def tools, do: [Legion.Tools.AgentTool]

  def tool_config(Legion.Tools.AgentTool), do: [agents: [MyApp.HNAgent, MyApp.RedditAgent]]
end
```

The LLM then writes code like:

```elixir
{:ok, hn} = Legion.Tools.AgentTool.call(MyApp.HNAgent, "Find Elixir posts")
{:ok, reddit} = Legion.Tools.AgentTool.call(MyApp.RedditAgent, "Find Elixir discussions")
# ... combine and analyze both results
```

## Configuration

```elixir
config :legion, :config, %{
  model: "openai:gpt-4o",
  max_iterations: 10,
  max_retries: 3,
  sandbox_timeout: 60_000
}
```

Agents override with `def config`:

```elixir
def config, do: %{model: "anthropic:claude-sonnet-4-20250514", max_iterations: 20}
```

## Agent Callbacks

All optional with sensible defaults:

| Callback          | Default                 | Description                             |
| ----------------- | ----------------------- | --------------------------------------- |
| `tools/0`         | `[]`                    | Tool modules available to the agent     |
| `description/0`   | `@moduledoc`            | Agent description for the system prompt |
| `output_schema/0` | `%{"type" => "string"}` | JSON Schema for structured output       |
| `tool_config/1`   | `[]`                    | Per-tool keyword config                 |
| `system_prompt/0` | auto-generated          | Override the entire system prompt       |
| `config/0`        | `%{}`                   | Model, timeouts, limits                 |

## Telemetry

```elixir
Legion.Telemetry.attach_default_logger()
```

Events: `[:legion, :agent, :started | :stopped]`, `[:legion, :agent, :message, :start | :stop]`, `[:legion, :iteration, :*]`, `[:legion, :llm, :request, :*]`, `[:legion, :sandbox, :eval, :*]`.

<!-- MDOC -->

## License

MIT License - see [LICENSE](LICENSE) for details.
