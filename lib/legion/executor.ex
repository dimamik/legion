defmodule Legion.Executor do
  @moduledoc """
  Drives the LLM thinking loop for a single agent turn.

  Given a complete message history, calls the LLM, parses its response, runs
  sandboxed code if needed, and recurses until the LLM signals completion.

  Pure function — no processes, no state. Returns the final result and updated
  message history so the caller can persist context across turns.
  """

  alias Legion.{Sandbox, Telemetry}

  @default_config %{
    model: "openai:gpt-4o-mini",
    max_iterations: 10,
    max_retries: 3,
    sandbox_timeout: 60_000
  }

  defp action_schema(agent_module) do
    %{
      "type" => "object",
      "required" => ["action", "code", "result"],
      "additionalProperties" => false,
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => ["eval_and_continue", "eval_and_complete", "return", "done"],
          "description" => """
          The action to take:
          - "eval_and_continue": Execute code and continue. Use when you need the result to proceed.
          - "eval_and_complete": Execute code and return its result as the final answer.
          - "return": Return a structured result without code execution. Use when you have all the information needed.
          - "done": Task complete with no result to return.
          """
        },
        "code" => %{
          "type" => "string",
          "description" =>
            "Elixir code to execute. Required for eval_* actions. Empty string otherwise."
        },
        "result" => agent_module.output_schema()
      }
    }
  end

  @doc """
  Runs the LLM loop against the given message history.

  `messages` must already include the system prompt and the current user message.

  Returns `{:ok, result, messages}` or `{:cancel, reason, messages}`.
  """
  def run(agent_module, messages, config) do
    config = Map.merge(@default_config, config)
    loop(agent_module, messages, config, 0, 0)
  end

  defp loop(agent_module, messages, config, iteration, retries) do
    if iteration >= config.max_iterations do
      {:cancel, :reached_max_iterations, messages}
    else
      Telemetry.span(
        [:legion, :iteration],
        %{agent: agent_module, iteration: iteration},
        fn ->
          {action, messages} = call_llm(agent_module, messages, config, iteration)
          result = handle_action(agent_module, messages, config, action, iteration, retries)
          {result, %{action: action["action"]}}
        end
      )
    end
  end

  defp call_llm(agent_module, messages, config, iteration) do
    Telemetry.span(
      [:legion, :llm, :request],
      %{
        agent: agent_module,
        model: config.model,
        message_count: length(messages),
        iteration: iteration
      },
      fn ->
        case ReqLLM.generate_object(config.model, messages, action_schema(agent_module)) do
          {:ok, response} ->
            action = response.object
            msgs = messages ++ [%{role: "assistant", content: Jason.encode!(action)}]
            {{action, msgs}, %{}}

          {:error, reason} ->
            raise "LLM request failed: #{inspect(reason)}"
        end
      end
    )
  end

  defp handle_action(
         _agent,
         messages,
         _config,
         %{"action" => "return", "result" => result},
         _i,
         _r
       ),
       do: {:ok, result, messages}

  defp handle_action(_agent, messages, _config, %{"action" => "done"}, _i, _r),
    do: {:ok, nil, messages}

  defp handle_action(agent, messages, config, %{"action" => eval, "code" => code}, i, retries)
       when eval in ["eval_and_continue", "eval_and_complete"] and code != "" do
    case eval_in_span(agent, code, config) do
      {:ok, result} ->
        messages = messages ++ [%{role: "user", content: format_result(result)}]

        if eval == "eval_and_continue",
          do: loop(agent, messages, config, i + 1, 0),
          else: {:ok, result, messages}

      {:error, error} ->
        handle_execution_error(agent, messages, config, error, i, retries)
    end
  end

  defp handle_action(agent, messages, config, action, i, retries),
    do:
      handle_execution_error(
        agent,
        messages,
        config,
        "Unexpected action: #{inspect(action)}",
        i,
        retries
      )

  defp eval_in_span(agent_module, code, config) do
    Telemetry.span([:legion, :sandbox, :eval], %{agent: agent_module, code: code}, fn ->
      case Sandbox.execute(code, agent_module.tools(), config.sandbox_timeout) do
        {:ok, value} -> {{:ok, value}, %{success: true, result: value}}
        {:error, error} -> {{:error, error}, %{success: false, error: error}}
      end
    end)
  end

  defp handle_execution_error(agent_module, messages, config, error, iteration, retries) do
    if retries >= config.max_retries do
      {:cancel, :reached_max_retries, messages}
    else
      error_text = format_error(error)

      messages =
        messages ++
          [
            %{
              role: "user",
              content:
                "Code execution failed:\n\n#{error_text}\n\nPlease fix the error and try again."
            }
          ]

      loop(agent_module, messages, config, iteration, retries + 1)
    end
  end

  defp format_result(result) do
    """
    Code executed successfully. Result:
    ```
    #{inspect(result, pretty: true, limit: 1000)}
    ```
    """
  end

  defp format_error(%{message: msg}) when is_binary(msg), do: msg
  defp format_error(error) when is_exception(error), do: Exception.message(error)
  defp format_error(error), do: inspect(error, pretty: true, limit: 50)
end
