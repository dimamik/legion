defmodule Legion.Executor do
  @moduledoc """
  Core execution loop for Legion agents.

  The executor orchestrates the interaction between the LLM and code sandbox,
  managing iterations, retries, and context preservation.
  """

  alias Legion.Config
  alias Legion.LLM.{ActionSchema, PromptBuilder}
  alias Legion.Observability.{LLMRequest, Telemetry}
  alias Legion.Sandbox

  @type context :: %{
          messages: list(map()),
          iteration: non_neg_integer(),
          retry: non_neg_integer()
        }

  @type run_result ::
          {:ok, any()}
          | {:cancel, :reached_max_iterations | :reached_max_retries}

  @doc """
  Runs an agent with the given task.

  ## Parameters
    - agent_module: The agent module implementing Legion.AIAgent
    - task: The task string to execute
    - opts: Optional configuration overrides

  ## Returns
    - `{:ok, result}` - Agent completed successfully
    - `{:cancel, reason}` - Agent was cancelled due to limits
  """
  @spec run(module(), String.t(), keyword()) :: run_result()
  def run(agent_module, task, opts \\ []) do
    config = Config.resolve(agent_module, opts)
    agent_info = agent_module.__legion_agent_info__()
    system_prompt = PromptBuilder.build_system_prompt(agent_module)

    setup_vault(agent_module, agent_info.tools)

    context = %{
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: task}
      ],
      iteration: 0,
      retry: 0
    }

    Telemetry.span([:legion, :call], %{agent: agent_module, task: task}, fn ->
      result = execution_loop(agent_module, context, config)

      case result do
        {:ok, value, final_context} ->
          {{:ok, value}, Map.put(final_context, :result, value)}

        {:cancel, reason, final_context} ->
          {{:cancel, reason}, final_context}
      end
    end)
    |> elem(0)
  end

  @doc """
  Continues execution with an existing context.

  Used by AgentServer for long-lived agents.
  """
  @spec continue(module(), context(), String.t(), Config.t()) :: run_result()
  def continue(agent_module, context, message, config) do
    # Only add a new message if it's not empty
    updated_messages =
      if message != "" do
        context.messages ++ [%{role: "user", content: message}]
      else
        context.messages
      end

    updated_context = %{
      context
      | messages: updated_messages,
        iteration: 0,
        retry: 0
    }

    case execution_loop(agent_module, updated_context, config) do
      {:ok, value, final_context} -> {:ok, value, final_context}
      {:cancel, reason, final_context} -> {:cancel, reason, final_context}
    end
  end

  defp setup_vault(agent_module, tools) do
    {tool_opts, aliases} =
      Enum.reduce(tools, {%{}, []}, &accumulate_tool_data(agent_module, &1, &2))

    Vault.unsafe_merge(tool_opts)
    Vault.unsafe_merge(%{__legion_aliases__: aliases})
  end

  defp accumulate_tool_data(agent_module, tool_module, {opts_acc, aliases_acc}) do
    opts = build_tool_opts(agent_module, tool_module)
    aliases = collect_aliases(tool_module, opts)

    {Map.put(opts_acc, tool_module, opts), aliases_acc ++ aliases}
  end

  defp build_tool_opts(agent_module, tool_module) do
    agent_module
    |> tool_module_opts(tool_module)
    |> normalize_allowed_agents()
  end

  defp tool_module_opts(agent_module, tool_module), do: agent_module.tool_options(tool_module)

  defp normalize_allowed_agents(opts) do
    case Map.get(opts, :allowed_agents) do
      agents when is_list(agents) ->
        Map.put(opts, :allowed_agents, Enum.map(agents, &to_string/1))

      _ ->
        opts
    end
  end

  defp collect_aliases(tool_module, opts) do
    if function_exported?(tool_module, :get_aliases, 1) do
      tool_module.get_aliases(opts)
    else
      []
    end
  end

  defp execution_loop(agent_module, context, config) do
    if context.iteration >= config.max_iterations do
      {:cancel, :reached_max_iterations, context}
    else
      result =
        Telemetry.span(
          [:legion, :iteration],
          %{agent: agent_module, iteration: context.iteration},
          fn ->
            execute_iteration(agent_module, context, config)
          end
        )

      case result do
        {:continue, next_context} -> execution_loop(agent_module, next_context, config)
        other -> other
      end
    end
  end

  defp execute_iteration(agent_module, context, config) do
    # Call LLM
    case call_llm(agent_module, context, config) do
      {:ok, object, _response} ->
        handle_llm_response(agent_module, context, config, object)

      {:error, reason} ->
        handle_llm_error(agent_module, context, config, reason)
    end
  end

  defp call_llm(agent_module, context, config) do
    messages = context.messages
    schema = ActionSchema.build(agent_module)

    # Build comprehensive request metadata for telemetry
    request = LLMRequest.new(config.model, messages, context.iteration, context.retry)

    Telemetry.span_with_metadata(
      [:legion, :llm, :request],
      %{agent: agent_module, model: config.model, request: request},
      fn ->
        result =
          case ReqLLM.generate_object(config.model, messages, schema) do
            {:ok, %{object: object} = response} ->
              {:ok, object, response}

            {:error, reason} ->
              {:error, reason}
          end

        # Return result and metadata to include in stop event
        extra_metadata =
          case result do
            {:ok, _object, response} -> %{response: response}
            {:error, _reason} -> %{}
          end

        {result, extra_metadata}
      end
    )
  end

  defp handle_llm_response(agent_module, context, config, response) do
    # Add assistant response to context (convert structured response to JSON string)
    response_text = Jason.encode!(response)
    context = add_message(context, "assistant", response_text)

    # Pattern match on the structured response (uses string keys from JSON)
    case response do
      %{"action" => "eval_and_continue", "code" => code} when is_binary(code) and code != "" ->
        execute_and_continue(agent_module, context, config, code)

      %{"action" => "eval_and_complete", "code" => code} when is_binary(code) and code != "" ->
        execute_and_complete(agent_module, context, config, code)

      %{"action" => "return", "result" => result} ->
        {:ok, result, context}

      %{"action" => "done"} ->
        {:ok, nil, context}

      invalid ->
        handle_parse_error(
          agent_module,
          context,
          config,
          "Invalid response structure: #{inspect(invalid)}"
        )
    end
  end

  defp execute_and_continue(agent_module, context, config, code) do
    case execute_code(agent_module, code, config) do
      {:ok, result} ->
        # Add result to context and continue
        result_message = format_execution_result(result)
        context = add_message(context, "user", result_message)
        updated_context = %{context | iteration: context.iteration + 1, retry: 0}
        {:continue, updated_context}

      {:error, error} ->
        handle_execution_error(agent_module, context, config, error)
    end
  end

  defp execute_and_complete(agent_module, context, config, code) do
    case execute_code(agent_module, code, config) do
      {:ok, result} ->
        {:ok, result, context}

      {:error, error} ->
        # On error, retry
        handle_execution_error(agent_module, context, config, error)
    end
  end

  defp execute_code(agent_module, code, config) do
    Telemetry.span(
      [:legion, :sandbox, :eval],
      %{agent: agent_module, code: code},
      fn ->
        # Get aliases from Vault
        aliases = Vault.get(:__legion_aliases__, [])

        # Merge base config with agent's custom sandbox options
        sandbox_opts =
          [timeout: config.sandbox.timeout, aliases: aliases]
          |> Keyword.merge(agent_module.sandbox_options())

        # Agent module itself implements Legion.Sandbox.Allowlist
        case Sandbox.eval(code, agent_module, sandbox_opts) do
          {:ok, result} -> {:ok, result}
          {:error, error} -> {:error, error}
        end
      end
    )
  end

  defp handle_execution_error(_agent_module, context, config, error) do
    if context.retry >= config.max_retries do
      {:cancel, :reached_max_retries, context}
    else
      error_message = format_error_for_llm(error)

      updated_context =
        context
        |> add_message(
          "user",
          "Code execution failed:\n\n#{error_message}\n\nPlease fix the error and try again."
        )
        |> Map.put(:retry, context.retry + 1)

      {:continue, updated_context}
    end
  end

  defp handle_parse_error(_agent_module, context, config, reason) do
    if context.retry >= config.max_retries do
      {:cancel, :reached_max_retries, context}
    else
      updated_context =
        context
        |> add_message(
          "user",
          "Invalid response format: #{reason}\n\nPlease respond with valid JSON in the expected format."
        )
        |> Map.put(:retry, context.retry + 1)

      {:continue, updated_context}
    end
  end

  defp handle_llm_error(_agent_module, _context, _config, reason) do
    # LLM errors should propagate immediately, not retry
    raise "LLM request failed: #{inspect(reason)}"
  end

  defp format_error_for_llm(%{message: message}) when is_binary(message) do
    message
  end

  defp format_error_for_llm(error) when is_exception(error) do
    Exception.message(error)
  end

  defp format_error_for_llm(error) do
    error
    |> inspect(pretty: true, limit: 50)
    |> String.slice(0, 2000)
  end

  defp add_message(context, role, content) do
    %{context | messages: context.messages ++ [%{role: role, content: content}]}
  end

  defp format_execution_result(result) do
    """
    Code executed successfully. Result:
    ```
    #{inspect(result, pretty: true, limit: 1000)}
    ```
    """
  end
end
