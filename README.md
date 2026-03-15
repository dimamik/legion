# Legion

[![CI](https://github.com/dimamik/legion/actions/workflows/ci.yml/badge.svg)](https://github.com/dimamik/legion/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/legion.svg)](https://github.com/dimamik/legion/blob/main/LICENSE)
[![Version](https://img.shields.io/hexpm/v/legion.svg)](https://hex.pm/packages/legion)
[![Hex Docs](https://img.shields.io/badge/documentation-gray.svg)](https://hexdocs.pm/legion)

<!-- MDOC -->

Legion is an Elixir-native framework for building AI agents. Unlike traditional function-calling approaches, Legion agents generate and execute actual Elixir code, giving them the full power of the language while staying safely sandboxed.

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

Agents are long or short-lived Elixir processes that maintain state and can be messaged.

```elixir
defmodule MyApp.ResearchAgent do
  @moduledoc """
  Fetch posts, evaluate their relevance and quality, and save the good ones.
  """
  use Legion.Agent

  def tools, do: [MyApp.Tools.ScraperTool, MyApp.Tools.DatabaseTool]
end
```

### 3. Run the Agent

```elixir
{:ok, result} = Legion.execute(MyApp.ResearchAgent, "Find cool Elixir posts about Advent of Code and save them")
# => {:ok, "Found 3 relevant posts and saved 2 that met quality criteria."}
```

## Features

- **Code Generation over Function Calling** - Agents write Elixir code instead of making dozens of tool-call round-trips. This makes them smarter and reduces the amount of tokens used. [See anthropic post about this](https://www.anthropic.com/engineering/code-execution-with-mcp).
- **Sandboxed Execution** - Generated code runs in a restricted environment with controlled access to tools. You have full control over which tools are exposed to which agents, and you can monitor agent behavior using the [`legion_web`](https://github.com/dimamik/legion_web) dashboard.
- **Simple Tool Definition** - Expose any Elixir module as a tool with `use Legion.Tool`. This allows you to reuse your existing app's logic. If you want to expose a third-party module as a set of tools, you can do that too.
- **Authorization baked in** - The safest way to authorize tool calls via the [`Vault`](https://github.com/dimamik/vault) library. Put all data needed to authorize an LLM call before starting the agent, and validate it inside the tool call. Everything will be available due to `Vault`'s nature.
- **Long-lived Agents** - Treat your agents as [GenServers](https://hexdocs.pm/elixir/GenServer.html), context is preserved naturally. Start your agent with `Legion.start_link/2`, just as you'd start a [GenServer](https://hexdocs.pm/elixir/GenServer.html). Agents can reference variables across turns (tasks) — just use the `share_bindings: true` option.
- **Multi-Agent Systems** - Agents can orchestrate other agents, letting you create complex systems that manage themselves. Agents spawn other agents as linked processes — when a parent dies, all children are stopped too. Your agent is just another BEAM process.
- **Human in the Loop** - Human-in-the-loop is just a built-in tool called `HumanTool`. You could have written it yourself, but I wrote it for you. It just blocks the agent's execution until it receives a message from the user. Simple as that.
- **Structured Output** - Define schemas to get typed, validated responses from agents, or omit types and operate on plain text. You have full control over prompts and schemas.
- **Configurable** - Global defaults with per-agent overrides for model, timeouts, and limits
- **Telemetry** - Built-in observability with events for calls, iterations, LLM requests, and more
- **All BEAM/Elixir features** - Since it's built on top of raw processes, everything that works with processes would work with Legion. In that: process groups, hot code reloading, processes being super lightweight and isolated, and many many more.

## Installation

Add `legion` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:legion, "~> 0.2"}
  ]
end
```

Configure your LLM API key (see [req_llm configuration](https://hexdocs.pm/req_llm/ReqLLM.html#module-configuration) for all options):

```elixir
# config/runtime.exs
config :req_llm, openai_api_key: System.get_env("OPENAI_API_KEY")
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
config :legion, :config, %{
  model: "openai:gpt-4o-mini",
  max_iterations: 10,
  max_retries: 3,
  sandbox_timeout: 60_000,
  share_bindings: false
}
```

- **Iterations** are successful execution steps - the agent fetches data, processes it, calls another tool, etc. Each productive action counts as one iteration.
- **Retries** are consecutive failures - when the LLM generates invalid code or a tool raises an error. The counter resets after each successful iteration.
- **share_bindings** — when `true`, variable bindings from code execution carry over between turns in a long-lived agent. For example, if the LLM assigns `posts = ScraperTool.fetch_posts()` in one turn, the `posts` variable will be available in the next turn. Defaults to `false` (each turn starts with a clean slate).

Agents can override global settings:

```elixir
defmodule MyApp.DataAgent do
  use Legion.Agent

  def tools, do: [MyApp.HTTPTool]
  def config, do: %{model: "anthropic:claude-sonnet-4-20250514", max_iterations: 5}
end
```

## Agent Callbacks

All callbacks are optional with sensible defaults:

| Callback          | Default                 | Description                             |
| ----------------- | ----------------------- | --------------------------------------- |
| `tools/0`         | `[]`                    | Tool modules available to the agent     |
| `description/0`   | `@moduledoc`            | Agent description for the system prompt |
| `output_schema/0` | `%{"type" => "string"}` | JSON Schema for structured output       |
| `tool_config/1`   | `[]`                    | Per-tool keyword config                 |
| `system_prompt/0` | auto-generated          | Override the entire system prompt       |
| `config/0`        | `%{}`                   | Model, timeouts, limits                 |

```elixir
defmodule MyApp.DataAgent do
  use Legion.Agent

  def tools, do: [MyApp.HTTPTool]

  # Structured output schema
  def output_schema do
    [
      summary: [type: :string, required: true],
      count: [type: :integer, required: true]
    ]
  end

  # Additional instructions for the LLM
  def system_prompt do
    "Always validate URLs before fetching. Prefer JSON responses."
  end

  # Pass options to specific tools (accessible via Vault)
  def tool_config(MyApp.HTTPTool), do: [timeout: 10_000]
end
```

## Authorization

To authorize tool calls for a specific user, put auth data into Vault before starting the agent and read it inside the tool. LLM-generated code has no access to Vault.

```elixir
# Before starting the agent
Vault.init(:current_user, %{id: user.id})

{:ok, result} = Legion.execute(MyApp.PostsAgent, "Find my posts from today and summarize them")
```

```elixir
# Inside your tool
defmodule MyApp.Tools.PostsTool do
  use Legion.Tool

  def get_my_posts do
    %{id: user_id} = Vault.get(:current_user)
    Repo.all(from p in Post, where: p.user_id == ^user_id)
  end
end
```

## Human in the Loop tool

Request human input during agent execution:

```elixir
# Agent can use built-in HumanTool (if you allow it to)
HumanTool.ask("Should I proceed with this operation?")

# Your application responds
Legion.call(agent_pid, {:respond, "Yes, proceed"})
```

## Multi-Agent Systems

Agents can spawn and communicate with other agents using the built-in `AgentTool`:

```elixir
defmodule MyApp.OrchestratorAgent do
  use Legion.Agent

  def tools, do: [Legion.Tools.AgentTool, MyApp.Tools.DatabaseTool]
  def tool_config(Legion.Tools.AgentTool), do: [agents: [MyApp.ResearchAgent, MyApp.WriterAgent]]
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

## Agent Pools

Since agents are regular BEAM processes, you can use Erlang's `:pg` (process groups) to create agent pools with no external infrastructure:

```elixir
# Spawn a pool of support agents
for _ <- 1..5 do
  {:ok, pid} = Legion.start_link(SupportAgent)
  :pg.join(:support_pool, pid)
end

# Route incoming tickets to the next available agent
defp handle_ticket(ticket) do
  pool = :pg.get_members(:support_pool)
  agent = Enum.random(pool)
  Legion.cast(agent, "Handle this support ticket: #{ticket}")
end
```

## Hot Code Reloading

Since tools and agents are regular Elixir modules, the BEAM's hot code reloading works out of the box. You can update tool implementations, swap agent behaviors, or add entirely new capabilities to running agents — without restarting the VM, without dropping conversations, without losing state.

## Telemetry

```elixir
Legion.Telemetry.attach_default_logger()
```

Legion emits telemetry events for observability:

- `[:legion, :agent, :started | :stopped]` - agent lifecycle
- `[:legion, :agent, :message, :start | :stop]` - per-message lifecycle
- `[:legion, :iteration, :start | :stop]` - each execution step
- `[:legion, :llm, :request, :start | :stop]` - LLM API calls
- `[:legion, :sandbox, :eval, :start | :stop]` - code evaluation
- `[:legion, :human, :input_required | :input_received]` - human-in-the-loop

Plus, Legion emits `Req` telemetry events for HTTP requests.

## Limitations

### Sandboxing

Legion's sandbox restricts what LLM-generated code can do — but it is not a full process isolation sandbox **yet**. Generated code runs inside the same BEAM VM as your application.

What the sandbox does:

- Blocks dangerous language constructs: `defmodule`, `import`, `spawn`, `send`, `receive`, `apply`, etc.
- Restricts module access to an explicit allowlist (standard library + your tools)
- Kills the evaluation process if it exceeds `sandbox_timeout`

What it does **not** do:

- Isolate memory — runaway allocations affect the whole VM
- Prevent atom table exhaustion — `String.to_atom/1` is available and atoms are never garbage collected
- Restrict access to the BEAM node name, process pid, or refs via `Kernel` functions

**The practical implication:** Legion is designed for trusted code generators (your own LLM-backed agents with controlled tool access), not for running arbitrary untrusted code from unknown sources. If your threat model requires full process isolation, you might want to spawn legion agents in an isolated BEAM instance.

<!-- MDOC -->

## License

MIT License - see [LICENSE](LICENSE) for details.
