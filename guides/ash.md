# Using Legion with Ash

Ash applications already have the two things a Legion tool needs: actions
that are the only way to touch data, and policies that decide who may call
them. Legion adds an agent that calls those actions through a small tool
module. No extension, no glue package - a `Legion.Tool` that calls your
domain's code interface with the actor from
[Vault](https://github.com/dimamik/vault).

This guide assumes the [integrating](integrating.md) guide's setup and a
domain like:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain

  resources do
    resource MyApp.Post do
      define :list_posts, action: :read
      define :create_post, action: :create, args: [:title, :body]
    end
  end
end
```

## 1. One tool per domain, actor from Vault

```elixir
defmodule MyApp.Tools.PostsTool do
  @moduledoc """
  The signed-in user's posts. Only their own posts are visible; a post
  needs a title and a body.
  """
  use Legion.Tool

  alias MyApp.Blog
  alias MyApp.Post

  @public_attributes Post |> Ash.Resource.Info.public_attributes() |> Enum.map(& &1.name)

  @doc "Posts of the signed-in user"
  def mine, do: Blog.list_posts!(actor: actor()) |> public()

  @doc ~S|Searches posts with a filter table, for example `{title = {eq = "Hello"}}`|
  def search(filter) do
    Post
    |> Ash.Query.filter_input(filter)
    |> Ash.Query.limit(50)
    |> Ash.read!(actor: actor())
    |> public()
  end

  @doc ~S|Creates a post from `{title = "...", body = "..."}`|
  def create(attributes) do
    Blog.create_post!(attributes["title"], attributes["body"], actor: actor()) |> public()
  end

  defp actor, do: Vault.get(:current_user)

  defp public(records) when is_list(records), do: Enum.map(records, &public/1)
  defp public(record), do: Map.take(record, @public_attributes)
end
```

Three things carry the weight here:

- **`actor: actor()` on every call.** Vault is visible inside the sandbox's
  eval process, but the generated code is not a `Legion.Tool`, so it cannot
  read Vault or pass an actor of its own. Policies run exactly as they do
  for any other caller. With no Vault at all the actor is `nil`, and
  policies decide what a nil actor may do - the safe way to fail.
- **`Ash.Query.filter_input/2` for anything the model wrote.** Lua tables
  arrive as string-keyed maps, which is the shape `filter_input`,
  `sort_input` and `for_create` take. Private and non-filterable fields are
  rejected with a readable error; field policies turn forbidden references
  into `nil`. The generated code never needs the `Ash.Query.filter` macro.
- **`public/1` on every result.** See the next section.

Front door, same as for any Legion app:

```elixir
Vault.init(current_user: socket.assigns.current_user)
{:ok, pid} = Legion.start_link(MyApp.WriterAgent)
```

If you already build an `Ash.Scope`, put that in Vault instead and pass
`scope: Vault.get(:scope)` to the actions - actor, tenant and context travel
together and both Ash and Legion see the same principal.

## 2. Return public attributes, not records

The Lua sandbox converts structs with `Map.from_struct`, so an Ash record
handed to the model as-is carries `__meta__`, `__metadata__`, empty
`aggregates` and `calculations`, `Ash.NotLoaded` tables for every unloaded
relationship - and **private and `sensitive?` attributes**. Ash's `Inspect`
redacts sensitive fields; the Lua boundary does not, and in the Elixir sandbox
generated code can read any field of the struct directly.

`Map.take(record, @public_attributes)` fixes both the token cost and the
leak. Add loaded relationships and calculations explicitly when the agent
needs them.

## 3. What not to do

- **Never allowlist `Ash`, `Ash.Query` or a domain module** in the Elixir
  sandbox. Generated code could pass its own `actor:` or
  `authorize?: false`. In the Lua sandbox this cannot happen - modules that
  are not a `Legion.Tool` expose no functions.
- **Keep `show_policy_breakdowns?` off in production.** The breakdown text
  reaches the model and, through it, the user.
- **Limit reads inside the tool.** Legion truncates results at
  `max_message_length` and the model then reasons over a cut-off table.

## 4. Errors reach the model

Forbidden and Invalid errors are rescued and re-raised as sandbox errors with
their message - `attribute title is required` is something the model can act
on. Each one costs a retry (`max_retries`, three by default), so say the
rules in the moduledoc, as above, rather than letting the model find them
by failing.

## 5. Agents inside actions

The reverse direction is a generic action:

```elixir
action :summarize, :string do
  argument :text, :string, allow_nil?: false

  run fn input, _context ->
    case Legion.execute(MyApp.SummaryAgent, input.arguments.text) do
      {:ok, summary} -> {:ok, summary}
      {:cancel, reason} -> {:error, reason}
    end
  end
end
```

Ash gets its actor from the action options, Legion's tools get theirs from
Vault, so initialize Vault once at the front door from the same scope you
hand to Ash. Do not `Vault.init` inside the action: it raises when an
ancestor process already did.

## 6. Shared infrastructure

- **Persistence and rate limiting** - `Legion.Store.Postgres` and
  `Legion.RateLimiter.Postgres` need an `Ecto.Repo`; an `AshPostgres.Repo`
  is one. The store migration is a plain `Ecto.Migration` and lives next to
  `mix ash.codegen` output.
- **Multitenancy** - `tenant:` is an Ash option like `actor:`; carry it in
  Vault or inside the scope and pass it the same way.
