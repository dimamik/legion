defmodule Legion.Tools.HumanTool do
  @moduledoc """
  Built-in tool for asking a human a question mid-execution.

  ## Configuration

  Configure via `tool_config/1` in your agent:

      def tool_config(Legion.Tools.HumanTool) do
        [handler: MyApp.ChatHandler, timeout: 30_000]
      end

  Options:

    - `:handler` (required) — a pid or registered name that receives
      `{:human_request, ref, from_pid, question, meta}` and must send
      `{:human_response, ref, answer}` back to `from_pid`.
    - `:timeout` — milliseconds to wait for a response. Defaults to `:infinity`.

  ## Usage (for LLM agent)

      Legion.Tools.HumanTool.ask("What format do you prefer?")
  """

  use Legion.Tool

  @doc """
  Asks a human a question and blocks until they respond.

  Returns the human's answer as a string.
  Use this tool with `eval_and_continue`.
  """
  def ask(question) when is_binary(question) do
    config = Vault.get(__MODULE__, [])
    handler = config[:handler]

    unless handler do
      raise ArgumentError,
            "HumanTool requires a handler; configure via tool_config/1: [handler: pid_or_name]"
    end

    timeout = config[:timeout] || :infinity
    ref = make_ref()
    send(handler, {:human_request, ref, self(), question, %{run_id: Vault.get(:run_id)}})

    receive do
      {:human_response, ^ref, answer} -> answer
    after
      timeout -> raise "HumanTool: timed out waiting for human response after #{timeout}ms"
    end
  end
end
