defmodule Legion.AgentPrompt do
  @moduledoc """
  This module is responsible for generating prompts for agents based on their definitions and the tools they have access to.
  """

  @template_path Path.join(__DIR__, "prompts/system_prompt.eex")
  @external_resource @template_path
  @template EEx.compile_file(@template_path)

  def system_prompt(agent) do
    tools = agent.tools()

    tool_contents = Enum.map(tools, & &1.description())

    description = agent.moduledoc()

    {result, _} =
      Code.eval_quoted(@template,
        description: description,
        tool_contents: tool_contents,
        elixir_version: System.version()
      )

    String.trim(result)
  end
end
