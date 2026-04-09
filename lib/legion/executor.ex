defmodule Legion.Executor do
  @moduledoc """
  Drives the LLM thinking loop for a single agent turn.

  Given a complete message history, calls the LLM, parses its response, runs
  sandboxed code if needed, and recurses until the LLM signals completion.

  Returns the final result and updated message history so the caller can persist
  context across turns.
  """

  alias Legion.{Sandbox, Telemetry}

  @default_config %{
    model: "openai:gpt-4o-mini",
    max_iterations: 10,
    max_retries: 3,
    sandbox_timeout: 60_000,
    share_bindings: false
  }

  @action_descriptions %{
    "eval_and_continue" => "Execute code and continue. Use when you need the result to proceed.",
    "eval_and_complete" => "Execute code and return its result as the final answer.",
    "return" => "Return a structured result without code execution.",
    "done" => "Task complete with no result to return."
  }

  defp action_schema(agent_module) do
    types = agent_module.action_types()

    description =
      types
      |> Enum.map_join("\n", fn t -> "- \"#{t}\": #{Map.fetch!(@action_descriptions, t)}" end)

    %{
      "type" => "object",
      "required" => ["action", "code", "result"],
      "additionalProperties" => false,
      "properties" => %{
        "action" => %{
          "type" => "string",
          "enum" => types,
          "description" => "The action to take:\n" <> description
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

  Returns `{:ok, result, messages, bindings}` or `{:cancel, reason, messages, bindings}`.
  """
  def run(agent_module, messages, config, bindings \\ []) do
    config = Map.merge(@default_config, config)
    loop(agent_module, messages, config, 0, 0, bindings)
  end

  defp loop(agent_module, messages, config, iteration, retries, bindings) do
    if iteration >= config.max_iterations do
      {:cancel, :reached_max_iterations, messages, bindings}
    else
      Telemetry.span(
        [:legion, :iteration],
        %{agent: agent_module, iteration: iteration},
        fn -> iterate(agent_module, messages, config, iteration, retries, bindings) end
      )
    end
  end

  defp iterate(agent_module, messages, config, iteration, retries, bindings) do
    # credo:disable-for-next-line
    try do
      with {:ok, action, messages} <- call_llm(agent_module, messages, config, iteration),
           :ok <- validate_action_type(agent_module, action) do
        result =
          handle_action(agent_module, messages, config, action, iteration, retries, bindings)

        {result, %{action: action["action"]}}
      else
        {:error, reason} ->
          result =
            handle_execution_error(
              agent_module,
              messages,
              config,
              reason,
              iteration,
              retries,
              bindings
            )

          {result, %{action: nil}}
      end
    rescue
      e ->
        result =
          handle_execution_error(agent_module, messages, config, e, iteration, retries, bindings)

        {result, %{action: nil}}
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
            action = extract_object(response)
            msgs = messages ++ [%{role: "assistant", content: Jason.encode!(action)}]
            {{:ok, action, msgs}, %{object: action}}

          {:error, reason} ->
            {{:error, "LLM request failed: #{inspect(reason)}"}, %{error: reason}}
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
         _r,
         bindings
       ),
       do: {:ok, result, messages, bindings}

  defp handle_action(_agent, messages, _config, %{"action" => "done"}, _i, _r, bindings),
    do: {:ok, nil, messages, bindings}

  defp handle_action(
         agent,
         messages,
         config,
         %{"action" => eval, "code" => code},
         i,
         retries,
         bindings
       )
       when eval in ["eval_and_continue", "eval_and_complete"] and code != "" do
    case eval_in_span(agent, code, config, bindings) do
      {:ok, {result, new_bindings}} ->
        messages = messages ++ [%{role: "user", content: format_result(result, new_bindings)}]

        if eval == "eval_and_continue",
          do: loop(agent, messages, config, i + 1, 0, new_bindings),
          else: {:ok, result, messages, new_bindings}

      {:error, error} ->
        handle_execution_error(agent, messages, config, error, i, retries, bindings)
    end
  end

  defp handle_action(agent, messages, config, action, i, retries, bindings),
    do:
      handle_execution_error(
        agent,
        messages,
        config,
        "Unexpected action: #{inspect(action)}",
        i,
        retries,
        bindings
      )

  defp eval_in_span(agent_module, code, config, bindings) do
    Telemetry.span([:legion, :sandbox, :eval], %{agent: agent_module, code: code}, fn ->
      allowed = agent_module.tools()

      case Sandbox.execute(code, config.sandbox_timeout, allowed, bindings) do
        {:ok, {value, new_bindings}} ->
          {{:ok, {value, new_bindings}}, %{success: true, result: value}}

        {:error, error} ->
          {{:error, error}, %{success: false, error: error}}
      end
    end)
  end

  defp handle_execution_error(agent_module, messages, config, error, iteration, retries, bindings) do
    if retries >= config.max_retries do
      {:cancel, :reached_max_retries, messages, bindings}
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

      loop(agent_module, messages, config, iteration, retries + 1, bindings)
    end
  end

  defp validate_action_type(agent_module, %{"action" => action_type}) do
    allowed = agent_module.action_types()

    if action_type in allowed do
      :ok
    else
      {:error,
       "Action #{inspect(action_type)} is not allowed for #{inspect(agent_module)}. " <>
         "Allowed: #{inspect(allowed)}"}
    end
  end

  defp validate_action_type(_agent_module, action) do
    {:error, "Response missing required 'action' field, got: #{inspect(action)}"}
  end

  defp extract_object(%{object: object}) when is_map(object), do: object

  defp extract_object(%{message: %{tool_calls: tool_calls}}) when is_list(tool_calls) do
    ReqLLM.ToolCall.find_args(tool_calls, "structured_output") ||
      raise "LLM response contained no structured object"
  end

  defp extract_object(_response), do: raise("LLM response contained no structured object")

  defp format_result(result, bindings) do
    var_names = bindings |> Keyword.keys() |> Enum.map(&"`#{&1}`")

    base = """
    Code executed successfully. Result:
    ```
    #{inspect(result, pretty: true, limit: 1000)}
    ```
    """

    if var_names == [] do
      base
    else
      base <> "\nAvailable variables: #{Enum.join(var_names, ", ")}"
    end
  end

  defp format_error(%{message: msg}) when is_binary(msg), do: msg
  defp format_error(error) when is_exception(error), do: Exception.message(error)
  defp format_error(error), do: inspect(error, pretty: true, limit: 50)
end
