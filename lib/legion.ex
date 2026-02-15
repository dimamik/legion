defmodule Legion do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  alias Legion.AgentServer

  @doc """
  Runs an agent on a single task and returns the result.

  Starts a temporary agent process, blocks until the task completes, then stops it.
  """
  def execute(agent_module, task) do
    {:ok, pid} = AgentServer.start_link(agent_module)
    result = AgentServer.call(pid, task)
    GenServer.stop(pid)
    result
  end

  @doc """
  Starts a long-lived agent process.

  ## Options
    - `:name` - register the process under a name
    - Any config overrides (`:model`, `:max_iterations`, etc.)
  """
  def start_link(agent_module, opts \\ []) do
    AgentServer.start_link(agent_module, opts)
  end

  @doc """
  Sends a message to a running agent and waits for the result.
  """
  def call(pid, message, timeout \\ :infinity) do
    AgentServer.call(pid, message, timeout)
  end

  @doc """
  Sends a message to a running agent without waiting for a result.
  """
  def cast(pid, message) do
    AgentServer.cast(pid, message)
  end
end
