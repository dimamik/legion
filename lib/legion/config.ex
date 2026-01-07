defmodule Legion.Config do
  @moduledoc """
  Configuration management for Legion agents.

  Configuration is resolved with the following priority (highest to lowest):
  1. Call options (passed to Legion.execute/3)
  2. Agent config (from agent's config/0 callback)
  3. Application environment
  4. Defaults
  """

  @defaults %{
    model: "openai:gpt-4o",
    timeout: 30_000,
    max_iterations: 10,
    max_retries: 3,
    sandbox: %{
      timeout: 5_000
    }
  }

  defstruct [
    :model,
    :timeout,
    :max_iterations,
    :max_retries,
    :sandbox
  ]

  @type t :: %__MODULE__{
          model: String.t(),
          timeout: pos_integer(),
          max_iterations: pos_integer(),
          max_retries: pos_integer(),
          sandbox: map()
        }

  @doc """
  Resolves configuration by merging defaults, app env, agent config, and call options.

  ## Parameters
    - agent_module: The agent module (must implement config/0 callback)
    - call_opts: Options passed to Legion.execute/3

  ## Returns
    A %Legion.Config{} struct with resolved configuration
  """
  @spec resolve(module(), keyword()) :: t()
  def resolve(agent_module, call_opts \\ []) do
    agent_config = get_agent_config(agent_module)
    app_config = get_app_config()

    merged =
      @defaults
      |> deep_merge(app_config)
      |> deep_merge(agent_config)
      |> deep_merge(Map.new(call_opts))

    struct!(__MODULE__, merged)
  end

  @doc """
  Returns the default configuration values.
  """
  @spec defaults() :: map()
  def defaults, do: @defaults

  defp get_agent_config(agent_module) do
    if function_exported?(agent_module, :config, 0) do
      agent_module.config() |> Map.new()
    else
      %{}
    end
  end

  defp get_app_config do
    app_env = Application.get_all_env(:legion)

    sandbox_config =
      case Keyword.get(app_env, :sandbox) do
        nil -> %{}
        config when is_list(config) -> Map.new(config)
        config when is_map(config) -> config
      end

    app_env
    |> Keyword.delete(:sandbox)
    |> Map.new()
    |> Map.put(:sandbox, sandbox_config)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _key, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end

  defp deep_merge(_left, right), do: right
end
