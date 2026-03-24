# Changelog

## v0.2.1 - 2026-03-24

- Improve source code extraction for tool definitions
- Adjust system prompt to better reflect capabilities


## v0.2.0 - 2026-03-15

### Changes

- Simplified and refactored internals
- Improved documentation and general library intent

---

## v0.1.0 - 2025-12-29

### New 🔥

- Initial release of Legion - an Elixir-native agentic AI framework
- `Legion.AIAgent` behaviour for building AI agents with customizable tools and configurations
- `Legion.Tool` behaviour for defining tools that agents can use
- Integration with `req_llm` for LLM communication
- `Legion.Sandbox` for secure code evaluation using Dune
- `Legion.call/2` and `Legion.cast/2` for synchronous and asynchronous message passing
- `Legion.start_link/2` for spawning long-lived agents
- Telemetry events for monitoring and debugging agent execution
- Support for agent-to-agent communication and delegation
