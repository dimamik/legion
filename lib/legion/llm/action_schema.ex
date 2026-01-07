defmodule Legion.LLM.ActionSchema do
  @moduledoc """
  Builds response schemas for LLM interactions based on agent output schema.

  This module creates JSON Schema compatible with OpenAI's strict mode that defines the
  structure of LLM responses. The schema includes action types and ensures
  that when the agent returns a result, it conforms to the agent's output_schema.
  """

  @doc """
  Builds the action schema for a given agent module.

  The schema includes:
  - `action`: One of "eval_and_continue", "eval_and_complete", "return", "done"
  - `code`: Elixir code to execute (optional, for eval_* actions)
  - `result`: Structured result conforming to the agent's output_schema (optional, for "return" action)

  ## Parameters
    - agent_module: The agent module implementing Legion.AIAgent

  ## Returns
    A JSON Schema map compatible with OpenAI's strict mode
  """
  @spec build(module()) :: map()
  def build(agent_module) do
    output_schema = agent_module.output_schema()
    result_schema = nimble_to_json_schema(output_schema)

    %{
      type: "object",
      properties: %{
        action: %{
          type: "string",
          enum: ["eval_and_continue", "eval_and_complete", "return", "done"],
          description: """
          The action to take next:
          - "eval_and_continue": Execute code and continue the loop with the result
          - "eval_and_complete": Execute code and return the result as the final answer
          - "return": Return a structured result immediately (no code execution)
          - "done": Task is complete, no result needed
          """
        },
        code: %{
          type: "string",
          description: """
          Elixir code to execute. Must be provided when action is "eval_and_continue" or "eval_and_complete". When action is "return" or "done", provide an empty string.
          This code will be evaluated in a sandboxed environment with access to the allowed tools.
          """
        },
        result: result_schema
      },
      required: ["action", "code", "result"],
      additionalProperties: false
    }
  end

  # Convert NimbleOptions schema to JSON Schema
  defp nimble_to_json_schema(nimble_schema) do
    properties =
      nimble_schema
      |> Enum.map(fn {key, opts} ->
        {to_string(key), nimble_type_to_json_schema(opts[:type])}
      end)
      |> Enum.into(%{})

    required_fields =
      nimble_schema
      |> Enum.filter(fn {_key, opts} -> Keyword.get(opts, :required, false) end)
      |> Enum.map(fn {key, _opts} -> to_string(key) end)

    %{
      type: "object",
      properties: properties,
      required: required_fields,
      additionalProperties: false,
      description:
        "Structured result conforming to the agent's output_schema. Should only be provided when action is 'return'. Otherwise - return an empty object."
    }
  end

  defp nimble_type_to_json_schema(:string), do: %{type: "string"}
  defp nimble_type_to_json_schema(:float), do: %{type: "number"}
  defp nimble_type_to_json_schema(:integer), do: %{type: "integer"}
  defp nimble_type_to_json_schema(:boolean), do: %{type: "boolean"}

  defp nimble_type_to_json_schema({:list, :string}),
    do: %{type: "array", items: %{type: "string"}}

  defp nimble_type_to_json_schema({:list, type}),
    do: %{type: "array", items: nimble_type_to_json_schema(type)}

  defp nimble_type_to_json_schema(_), do: %{type: "string"}
end
