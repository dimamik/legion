defmodule Legion.Sandbox do
  @moduledoc """
  Sandboxed code evaluation with AST-based security.

  Provides a secure environment for executing LLM-generated Elixir code
  with configurable module allowlists and timeout enforcement.

  Unlike Dune, this implementation:
  - Only performs static AST analysis (no runtime wrapping)
  - Only enforces timeout (no memory or reduction limits)
  - Uses simple Task-based execution with timeout
  """

  alias Legion.Sandbox.ASTAnalyzer

  @default_timeout 5000

  @doc """
  Evaluates code in a sandboxed environment.

  ## Parameters
    - code: The Elixir code string to evaluate
    - allowlist: Module implementing `Legion.Sandbox.Allowlist` behaviour
    - opts: Options including:
      - `:timeout` - Max execution time in ms (default: #{@default_timeout})

  ## Returns
    - `{:ok, result}` - Code executed successfully
    - `{:error, reason}` - Execution failed (with error map)

  ## Example

      iex> Legion.Sandbox.eval("1 + 2", Legion.Sandbox.DefaultAllowlist)
      {:ok, 3}

      iex> Legion.Sandbox.eval("File.cwd!()", Legion.Sandbox.DefaultAllowlist)
      {:error, %{type: :restricted, message: "module File is restricted"}}
  """
  @spec eval(String.t(), module(), keyword()) :: {:ok, any()} | {:error, map()}
  def eval(code, allowlist, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    aliases = Keyword.get(opts, :aliases, [])

    with {:ok, ast} <- parse_code(code),
         :ok <- ASTAnalyzer.analyze(ast, allowlist, aliases: aliases) do
      ast_with_aliases = inject_aliases(ast, aliases)
      execute_with_timeout(ast_with_aliases, timeout)
    end
  end

  # Injects alias statements at the beginning of the code block
  # aliases is a list of {ShortName, FullModule} tuples
  defp inject_aliases(ast, []), do: ast

  defp inject_aliases(ast, aliases) do
    alias_statements =
      Enum.map(aliases, fn {short_name, full_module} ->
        {:alias, [context: Elixir],
         [
           {:__aliases__, [alias: false], module_parts(full_module)},
           [as: {:__aliases__, [alias: false], [short_name]}]
         ]}
      end)

    {:__block__, [], alias_statements ++ [ast]}
  end

  # TODO: Come back to this and fix atom conversion
  defp module_parts(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_code(code) do
    case Code.string_to_quoted(code) do
      {:ok, ast} ->
        {:ok, ast}

      {:error, {location, error, token}} ->
        line = Keyword.get(location, :line, 1)
        message = "** (SyntaxError) nofile:#{line}: #{error}#{token}"
        {:error, %{type: :parsing, message: message}}
    end
  end

  defp execute_with_timeout(ast, timeout) do
    # Use Task for timeout enforcement
    task =
      Task.async(fn ->
        try do
          {result, _binding} = Code.eval_quoted(ast, [])
          {:ok, result}
        rescue
          e ->
            {:exception, Exception.message(e)}
        catch
          :throw, value ->
            {:throw, value}

          :exit, reason ->
            {:exit, reason}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, result}} ->
        {:ok, result}

      {:ok, {:exception, message}} ->
        {:error, %{type: :exception, message: message}}

      {:ok, {:throw, value}} ->
        {:error, %{type: :throw, message: "** (throw) #{inspect(value)}"}}

      {:ok, {:exit, reason}} ->
        {:error, %{type: :exit, message: "** (exit) #{inspect(reason)}"}}

      nil ->
        {:error, %{type: :timeout, message: "Execution timed out after #{timeout}ms"}}
    end
  end
end
