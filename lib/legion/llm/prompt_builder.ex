defmodule Legion.LLM.PromptBuilder do
  @moduledoc """
  Builds system prompts for Legion AI agents using EEx templates.
  """

  require EEx

  @doc """
  Builds the complete system prompt for an agent.
  """
  @spec build_system_prompt(module()) :: String.t()
  def build_system_prompt(agent_module) do
    agent_info = agent_module.__legion_agent_info__()

    render_prompt(
      agent_description: agent_info.moduledoc,
      tools: format_tools(agent_info.tools, agent_module),
      output_schema: format_output_schema(agent_module.output_schema()),
      custom_instructions: agent_module.system_prompt()
    )
    |> String.trim()
  end

  @templates_dir Path.join(__DIR__, "templates")

  EEx.function_from_file(:defp, :render_prompt, Path.join(@templates_dir, "prompt.eex"), [
    :assigns
  ])

  defp format_tools(tools, agent_module) do
    Enum.map(tools, &format_tool(&1, agent_module))
  end

  defp format_tool(tool_module, agent_module) do
    tool_info = tool_module.__tool_info__()
    tool_opts = agent_module.tool_options(tool_module)
    module_name = inspect(tool_module)
    dynamic_doc = get_dynamic_doc(tool_module, tool_opts)
    description = get_tool_description(tool_module, tool_info.moduledoc)

    render_tool(
      module_name: module_name,
      moduledoc: description,
      dynamic_doc: dynamic_doc,
      functions: Enum.map(tool_info.functions, &format_function(module_name, &1))
    )
  end

  EEx.function_from_file(:defp, :render_tool, Path.join(@templates_dir, "tool.eex"), [:assigns])

  defp format_function(module_name, %{name: name, params: params, doc: doc}) do
    params_str = Enum.map_join(params, ", ", &to_string/1)
    signature = "#{module_name}.#{name}(#{params_str})"

    if doc do
      "- `#{signature}`\n  #{indent_doc(doc)}"
    else
      "- `#{signature}`"
    end
  end

  defp indent_doc(text) do
    text |> String.split("\n") |> Enum.map_join("\n  ", &String.trim/1)
  end

  defp get_tool_description(tool_module, fallback) do
    if function_exported?(tool_module, :tool_description, 0) do
      tool_module.tool_description()
    else
      fallback
    end
  end

  defp get_dynamic_doc(tool_module, opts) do
    if function_exported?(tool_module, :dynamic_doc, 1) do
      tool_module.dynamic_doc(opts)
    end
  end

  defp format_output_schema(schema) do
    if schema && schema != [response: [type: :string, required: true]] do
      json = schema |> schema_to_example() |> Jason.encode!(pretty: true)
      "\nWhen using \"return\", your result must match:\n```json\n#{json}\n```"
    else
      ""
    end
  end

  defp schema_to_example(schema) do
    Map.new(schema, fn {key, opts} ->
      {to_string(key), type_example(opts[:type])}
    end)
  end

  defp type_example(:string), do: "string"
  defp type_example(:float), do: 0.0
  defp type_example(:integer), do: 0
  defp type_example(:boolean), do: true
  defp type_example({:list, t}), do: [type_example(t)]
  defp type_example(_), do: "value"
end
