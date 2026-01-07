defmodule Legion.Tools.HumanTool do
  # TODO: This needs to be overrideable, so that we can use Slack/Telegram, etc.
  # First PoC needs to use Telegram
  @moduledoc """
  Built-in tool for human-in-the-loop interactions.

  This tool allows agents to request input from a human operator,
  enabling scenarios where human judgment or approval is needed.

  When called, the agent execution is suspended until a human provides
  a response via `Legion.call(pid, {:respond, response})`.

  ## Configuration

  Configure timeout via `tool_options/1`:

      defmodule MyApp.ApprovalAgent do
        use Legion.AIAgent, tools: [Legion.Tools.HumanTool, ...]

        @impl true
        def tool_options(Legion.Tools.HumanTool) do
          %{
            timeout: 300_000  # 5 minutes
          }
        end
      end

  ## Telemetry Events

  - `[:legion, :human, :input_required]` - Emitted when input is requested
  - `[:legion, :human, :input_received]` - Emitted when input is received
  """

  use Legion.Tool

  @doc """
  Asks the human for free-form input.

  Suspends agent execution until a response is received.

  ## Parameters
    - question: The question to ask the human

  ## Returns
    The human's response as a string

  ## Example

      response = Legion.Tools.HumanTool.ask("What should we name this file?")
  """
  @spec ask(String.t()) :: String.t()
  def ask(question) do
    request_input(question, :ask)
  end

  @doc """
  Asks the human to choose from a list of options.

  Suspends agent execution until a choice is made.

  ## Parameters
    - question: The question to ask
    - options: List of options to choose from

  ## Returns
    The selected option

  ## Example

      choice = Legion.Tools.HumanTool.choose(
        "Which database should we use?",
        ["PostgreSQL", "MySQL", "SQLite"]
      )
  """
  @spec choose(String.t(), [String.t()]) :: String.t()
  def choose(question, options) when is_list(options) do
    formatted_question = format_choices(question, options)
    request_input(formatted_question, :choose)
  end

  @doc """
  Asks the human for a yes/no confirmation.

  Suspends agent execution until a response is received.

  ## Parameters
    - question: The yes/no question to ask

  ## Returns
    - `true` if confirmed
    - `false` if declined

  ## Example

      if Legion.Tools.HumanTool.confirm("Delete all files in /tmp?") do
        # proceed with deletion
      end
  """
  @spec confirm(String.t()) :: boolean()
  def confirm(question) do
    response = request_input("#{question} (yes/no)", :confirm)

    case String.downcase(String.trim(to_string(response))) do
      answer when answer in ["yes", "y", "true", "1"] -> true
      _ -> false
    end
  end

  defp request_input(question, type) do
    # Get the agent server pid from the process - it should be set by the executor
    case Process.get(:legion_agent_server) do
      nil ->
        # Fallback for one-off agents - just return a placeholder
        # In practice, HumanTool should mainly be used with long-lived agents
        raise "HumanTool requires a long-lived agent (started with Legion.start_link)"

      agent_pid ->
        Legion.AgentServer.request_human_input(agent_pid, question, type)
    end
  end

  defp format_choices(question, options) do
    choices =
      options
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {option, index} -> "  #{index}. #{option}" end)

    "#{question}\n#{choices}"
  end
end
