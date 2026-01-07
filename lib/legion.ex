defmodule Legion do
  @external_resource readme = Path.join([__DIR__, "../README.md"])

  @moduledoc readme
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  alias Legion.{AgentServer, Executor}

  @doc """
  Executes an agent with the given task synchronously.

  This is a one-off execution - the agent completes the task and returns.

  ## Parameters
    - agent_module: The agent module implementing Legion.AIAgent
    - task: The task string for the agent to execute
    - opts: Optional configuration overrides
      - `:model` - LLM model to use (e.g., "openai:gpt-4o")
      - `:timeout` - Request timeout in ms
      - `:max_iterations` - Maximum successful iterations
      - `:max_retries` - Maximum consecutive retries on error

  ## Returns
    - `{:ok, result}` - Agent completed successfully with result
    - `{:cancel, :reached_max_iterations}` - Hit iteration limit
    - `{:cancel, :reached_max_retries}` - Hit retry limit

  ## Example

      {:ok, result} = Legion.execute(MyApp.DataAgent, "Fetch and summarize https://example.com")
  """
  @spec execute(module(), String.t(), keyword()) :: {:ok, any()} | {:cancel, atom()}
  def execute(agent_module, task, opts \\ []) do
    Executor.run(agent_module, task, opts)
  end

  @doc """
  Starts a long-lived agent process.

  The agent maintains context between messages, allowing for
  multi-turn conversations.

  ## Parameters
    - agent_module: The agent module implementing Legion.AIAgent
    - initial_task: The initial task to start with
    - opts: Optional configuration and GenServer options
      - `:name` - GenServer name registration
      - Plus any Legion.execute/3 options

  ## Returns
    - `{:ok, pid}` - Agent started successfully
    - `{:error, reason}` - Failed to start

  ## Example

      {:ok, pid} = Legion.start_link(MyApp.AssistantAgent, "Hello, I need help with...")
  """
  @spec start_link(module(), String.t(), keyword()) :: GenServer.on_start()
  def start_link(agent_module, initial_task, opts \\ []) do
    AgentServer.start_link(agent_module, initial_task, opts)
  end

  @doc """
  Sends an asynchronous message to a long-lived agent.

  The message is added to the agent's context and processed.
  Does not wait for a response.

  ## Parameters
    - agent: The agent pid or registered name
    - message: The message to send

  ## Returns
    - `:ok`

  ## Example

      Legion.cast(agent_pid, "Please also check the footer section")
  """
  @spec cast(GenServer.server(), String.t()) :: :ok
  def cast(agent, message) do
    AgentServer.cast(agent, message)
  end

  @doc """
  Sends a synchronous message to a long-lived agent.

  Waits for the agent to process the message and return a result.
  Can also be used to provide a human response using `{:respond, response}`.

  ## Parameters
    - agent: The agent pid or registered name
    - message: The message to send (String or `{:respond, response}`)
    - timeout: Optional timeout in ms (default: 30_000)

  ## Returns
    - `{:ok, result}` - Agent responded with result
    - `{:cancel, reason}` - Agent hit limits
    - `:ok` - Response delivered (when using `{:respond, response}`)
    - `{:error, :no_pending_request}` - No pending human input request (when using `{:respond, response}`)

  ## Example

      {:ok, response} = Legion.call(agent_pid, "What did you find?")
      :ok = Legion.call(agent_pid, {:respond, "Yes, proceed"})
  """
  @spec call(GenServer.server(), String.t() | {:respond, any()}, timeout()) ::
          {:ok, any()} | {:cancel, atom()} | :ok | {:error, atom()}
  def call(agent, message, timeout \\ 30_000) do
    AgentServer.call(agent, message, timeout)
  end
end
