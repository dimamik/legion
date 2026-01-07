# Legion

> [!WARNING]
> The project is in early stages of development. Expect breaking changes in future releases.

<!-- MDOC -->

Legion is an Elixir-native framework for building AI agents. Unlike traditional function-calling approaches, Legion agents generate and execute actual Elixir code, giving them the full power of the language while staying safely sandboxed.

## Features

- **Code Generation over Function Calling** - Agents write expressive Elixir pipelines instead of making dozens of tool-call round-trips. This makes your agents smarter and reduces amount of tokens being used. [See anthropic post about this](https://www.anthropic.com/engineering/code-execution-with-mcp).
- **Sandboxed Execution** - Generated code runs in a restricted environment with controlled access to tools. You can define memory, time, and call limits.
- **Simple Tool Definition** - Expose any Elixir module as a tool with `use Legion.Tool`. You can reuse your existing app logic.
- **Authorization baked in** - The safest way to authorize tool calls via [`Vault`](https://github.com/dimamik/vault) library. Put all data needed to authorize LLM call before starting Agent, and validate it inside the tool call. Everything will be available due to the `Vault`'s nature.
- **Long-lived Agents** - Maintain context across multi-turn conversations with `start_link/2`.
- **Multi-Agent Systems** - Agents can orchestrate other agents, letting you create complex systems that will manage themselves.
- **Human in the Loop** - Pause execution to request human input when needed
- **Structured Output** - Define schemas to get typed, validated responses from agents, or omit types and operate on plain text. You have full conrol over prompts and schemas.
- **Configurable** - Global defaults with per-agent overrides for model, timeouts, and limits
- **Telemetry** - Built-in observability with events for calls, iterations, LLM requests, and more

## Installation

Add `legion` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:legion, "~> 0.1"}
  ]
end
```

Configure your LLM API key (see [req_llm configuration](https://hexdocs.pm/req_llm/ReqLLM.html#module-configuration) for all options):

```elixir
# config/runtime.exs
config :req_llm, openai_api_key: System.get_env("OPENAI_API_KEY")
```

## Quick Start

### 1. Define your tools

Tools are regular Elixir modules that expose functions to your agents:

```elixir
defmodule MyApp.Tools.ScraperTool do
  use Legion.Tool

  @doc "Fetches recent posts from HackerNews"
  def fetch_posts do
    Req.get!("https://hn.algolia.com/api/v1/search_by_date").body["hits"]
  end
end

defmodule MyApp.Tools.DatabaseTool do
  use Legion.Tool

  @doc "Saves a post title to the database"
  def insert_post(title), do: Repo.insert!(%Post{title: title})
end
```

### 2. Define an Agent

```elixir
defmodule MyApp.ResearchAgent do
  @moduledoc """
  Fetch posts, evaluate their relevance and quality, and save the good ones.
  """
  use Legion.AIAgent, tools: [MyApp.Tools.ScraperTool, MyApp.Tools.DatabaseTool]
end
```

### 3. Run the Agent

```elixir
{:ok, result} = Legion.execute(MyApp.ResearchAgent, "Find cool Elixir posts about Advent of Code and save them")
# => {:ok, "Found 3 relevant posts and saved 2 that met quality criteria."}
```

## How It Works

When you ask an agent: _"Find cool Elixir posts about Advent of Code and save them"_

The agent first fetches and filters relevant posts:

```elixir
ScraperTool.fetch_posts()
|> Enum.filter(fn post ->
  title = String.downcase(post["title"] || "")
  String.contains?(title, "elixir") and String.contains?(title, "advent")
end)
```

The LLM reviews the results, decides which posts are actually "cool", then saves them:

```elixir
["Elixir Advent of Code 2024 - Day 5 walkthrough", "My first AoC in Elixir!"]
|> Enum.each(&DatabaseTool.insert_post/1)
```

Traditional function-calling would need dozens of round-trips. Legion lets the LLM write expressive pipelines and make subjective judgments **at the same time**.

## Long-lived Agents

For multi-turn conversations or persistent agents:

```elixir
# Start an agent that maintains context
{:ok, pid} = Legion.start_link(MyApp.AssistantAgent, "Help me analyze this data")

# Send follow-up messages
{:ok, response} = Legion.call(pid, "Now filter for items over $100")

# Or fire-and-forget
Legion.cast(pid, "Also check the reviews")
```

## Configuration

Configure Legion in your `config/config.exs`:

```elixir
config :legion,
  model: "openai:gpt-4o",
  timeout: 30_000,
  max_iterations: 10,
  max_retries: 3
```

- **Iterations** are successful execution steps - the agent fetches data, processes it, calls another tool, etc. Each productive action counts as one iteration.
- **Retries** are consecutive failures - when the LLM generates invalid code or a tool raises an error. The counter resets after each successful iteration.

Agents can override global settings:

```elixir
defmodule MyApp.DataAgent do
  use Legion.AIAgent, tools: [MyApp.HTTPTool]

  @impl true
  def config do
    %{model: "anthropic:claude-sonnet-4-20250514", max_iterations: 5}
  end
end
```

## Agent Callbacks

All callbacks are optional with sensible defaults:

```elixir
defmodule MyApp.DataAgent do
  use Legion.AIAgent, tools: [MyApp.HTTPTool]

  # Structured output schema
  @impl true
  def output_schema do
    [
      summary: [type: :string, required: true],
      count: [type: :integer, required: true]
    ]
  end

  # Additional instructions for the LLM
  @impl true
  def system_prompt do
    "Always validate URLs before fetching. Prefer JSON responses."
  end

  # Pass options to specific tools (accessible via Vault)
  @impl true
  def tool_options(MyApp.HTTPTool), do: %{timeout: 10_000}
end
```

## Human in the Loop

Request human input during agent execution:

```elixir
# Agent can use the built-in HumanTool
Legion.Tools.HumanTool.ask("Should I proceed with this operation?")

# Your application responds
Legion.call(agent_pid, {:respond, "Yes, proceed"})
```

## Multi-Agent Systems

Agents can spawn and communicate with other agents using the built-in `AgentTool`:

```elixir
defmodule MyApp.OrchestratorAgent do
  use Legion.AIAgent, tools: [Legion.Tools.AgentTool, MyApp.Tools.DatabaseTool]

  @impl true
  def tool_options(Legion.Tools.AgentTool) do
    %{allowed_agents: [MyApp.ResearchAgent, MyApp.WriterAgent]}
  end
end
```

**The orchestrator agent** can then delegate tasks:

```elixir
# One-off task delegation
{:ok, research} = AgentTool.call(MyApp.ResearchAgent, "Find info about Elixir 1.18")

# Start a long-lived sub-agent
{:ok, pid} = AgentTool.start_link(MyApp.WriterAgent, "Write a blog post")
AgentTool.cast(pid, "Add a section about pattern matching")
{:ok, draft} = AgentTool.call(pid, "Show me what you have so far")
```

## Telemetry

Legion emits telemetry events for observability:

- `[:legion, :call, :start | :stop | :exception]` - agent call lifecycle
- `[:legion, :iteration, :start | :stop]` - each execution step
- `[:legion, :llm, :request, :start | :stop]` - LLM API calls
- `[:legion, :sandbox, :eval, :start | :stop]` - code evaluation
- `[:legion, :human, :input_required | :input_received]` - human-in-the-loop

Plus, Legion emits `Req` telemetry events for HTTP requests.

<!-- MDOC -->

## License

MIT License - see [LICENSE](LICENSE) for details.
