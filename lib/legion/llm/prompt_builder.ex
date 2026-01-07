defmodule Legion.LLM.PromptBuilder do
  # TODO: We need to streamline this, PLUS, data about tools is not looking
  # Good enough
  @moduledoc """
  Builds system prompts for Legion AI agents.

  The system prompt is constructed in the following order:
  1. Introduction (explains what a Legion agent is)
  2. Agent description (from agent's @moduledoc)
  3. Tool documentation (formatted from each tool's @moduledoc + @doc)
  4. Response format instructions (action types + output schema)
  5. Rules about code execution
  6. Custom instructions from agent's system_prompt/0 callback (appended last)
  """

  @doc """
  Builds the complete system prompt for an agent.

  ## Parameters
    - agent_module: The agent module implementing Legion.AIAgent

  ## Returns
    A string containing the full system prompt
  """
  @spec build_system_prompt(module()) :: String.t()
  def build_system_prompt(agent_module) do
    agent_info = agent_module.__legion_agent_info__()
    output_schema = agent_module.output_schema()
    custom_prompt = agent_module.system_prompt()

    [
      build_introduction(),
      build_agent_description(agent_info),
      build_tools_documentation(agent_info.tools, agent_module),
      build_response_format(output_schema),
      build_execution_rules(),
      build_custom_instructions(custom_prompt)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp build_introduction do
    """
    You are an AI agent that accomplishes tasks by writing Elixir code. Your code runs in a sandbox and you receive execution results to iterate until the task is complete.
    Before returning a final answer, ensure that all aspects of the user's request have been addressed.
    """
    |> String.trim()
  end

  defp build_agent_description(agent_info) do
    case agent_info.moduledoc do
      nil ->
        nil

      doc ->
        """
        # Agent Description

        #{doc}
        """
    end
  end

  defp build_tools_documentation([], _agent_module), do: nil

  defp build_tools_documentation(tools, agent_module) do
    tools_docs = Enum.map_join(tools, "\n\n", &format_tool_doc(&1, agent_module))

    """
    # Available Tools

    You have access to the following Elixir modules and their functions:

    #{tools_docs}
    """
  end

  defp format_tool_doc(tool_module, agent_module) do
    tool_info = tool_module.__tool_info__()
    tool_opts = agent_module.tool_options(tool_module)
    module_name = inspect(tool_module)

    # Get dynamic documentation if the tool implements it
    dynamic_doc = get_dynamic_doc(tool_module, tool_opts)

    header =
      case {tool_info.moduledoc, dynamic_doc} do
        {nil, nil} -> "## #{module_name}"
        {nil, dyn} -> "## #{module_name}\n\n#{dyn}"
        {doc, nil} -> "## #{module_name}\n\n#{doc}"
        {doc, dyn} -> "## #{module_name}\n\n#{doc}\n\n#{dyn}"
      end

    functions_doc =
      Enum.map_join(tool_info.functions, "\n\n", &format_function_doc(module_name, &1))

    """
    #{header}

    ### Functions

    #{functions_doc}
    """
  end

  defp get_dynamic_doc(tool_module, opts) do
    if function_exported?(tool_module, :dynamic_doc, 1) do
      tool_module.dynamic_doc(opts)
    else
      nil
    end
  end

  defp format_function_doc(module_name, %{name: name, params: params, doc: doc}) do
    params_str = Enum.map_join(params, ", ", &to_string/1)
    signature = "#{module_name}.#{name}(#{params_str})"

    case doc do
      nil -> "- `#{signature}`"
      doc_text -> "- `#{signature}`\n  #{format_doc_indent(doc_text)}"
    end
  end

  defp format_doc_indent(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n  ", &String.trim/1)
  end

  defp build_response_format(output_schema) do
    schema_section =
      if output_schema && output_schema != [response: [type: :string, required: true]] do
        json_example = nimble_schema_to_json_example(output_schema)

        """

        When using the "return" action, your result must have these fields:
        ```json
        #{Jason.encode!(json_example, pretty: true)}
        ```
        """
      else
        ""
      end

    """
    # Response Format

    You must respond with a structured object in one of the following formats:

    1. **Evaluate code and continue** - Execute code and continue the conversation:
    ```json
    {"action": "eval_and_continue", "code": "Elixir.Code.Here()"}
    ```

    2. **Evaluate code and complete** - Execute code and return its result as the final answer:
    ```json
    {"action": "eval_and_complete", "code": "Elixir.Code.Here()"}
    ```

    3. **Return result directly** - Return a structured result without code execution:
    ```json
    {"action": "return", "result": {"your": "result"}}
    ```

    4. **Done** - Task is finished, no result needed:
    ```json
    {"action": "done"}
    ```
    #{schema_section}
    """
  end

  # Convert NimbleOptions schema to a JSON example object
  defp nimble_schema_to_json_example(nimble_schema) do
    nimble_schema
    |> Enum.map(fn {key, opts} ->
      {to_string(key), type_to_example_value(opts[:type])}
    end)
    |> Enum.into(%{})
  end

  defp type_to_example_value(:string), do: "string"
  defp type_to_example_value(:float), do: 0.0
  defp type_to_example_value(:integer), do: 0
  defp type_to_example_value(:boolean), do: true
  defp type_to_example_value({:list, :string}), do: ["string"]
  defp type_to_example_value({:list, type}), do: [type_to_example_value(type)]
  defp type_to_example_value(_), do: "value"

  defp build_execution_rules do
    """
    # Code Execution Rules

    1. **Code Execution**: Your code will be executed in a sandboxed environment. Only the tool modules listed above are available.

    2. **No Shared State**: Each code execution is independent. Variables from previous executions are not available.

    3. **Error Handling**: If your code produces an error, you will receive the error message and can try again with corrected code.

    4. **Idempotency**: Be aware that some operations may not be idempotent. Track what has been successfully executed to avoid duplicate operations.

    5. **Code Style**: Write clean, functional Elixir code. Use pipelines where appropriate. The result of the last expression is returned.

    6. **Module Prefixes**: Always use the full module name when calling tool functions (e.g., `MyApp.HTTPTool.fetch(url)` not `fetch(url)`).
    """
  end

  defp build_custom_instructions(nil), do: nil

  defp build_custom_instructions(prompt) do
    """
    # Additional Instructions

    #{prompt}
    """
  end
end
