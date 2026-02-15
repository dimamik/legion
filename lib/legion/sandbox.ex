defmodule Legion.Sandbox do
  @moduledoc """
  Sandboxed code evaluation with AST-level safety checks.

  Evaluates Elixir code strings in a spawned process with:

  - **AST validation** — before evaluation, the code is parsed and walked to reject
    dangerous forms (`defmodule`, `import`, `spawn`, `send`, `receive`, etc.)
    and calls to modules not in the allow-list.
  - **Module allow-list** — only built-in safe modules (Kernel, Enum, Map, String, …)
    and explicitly passed modules may be called. If only some functions from a module
    should be exposed, wrap them in a dedicated facade module.
  - **Timeout** — evaluation runs in a monitored process that is killed if it exceeds
    the deadline (default 15 s).

  ## Examples

      iex> Legion.Sandbox.execute("2 + 2")
      {:ok, 4}

      iex> Legion.Sandbox.execute("Enum.sum([1, 2, 3])")
      {:ok, 6}

      iex> Legion.Sandbox.execute("System.halt()")
      {:error, "Module System is not allowed"}

      iex> Legion.Sandbox.execute("import Enum")
      {:error, "import is not allowed"}
  """

  alias Legion.Sandbox.ASTChecker

  @doc """
  Evaluates `code_string` in a sandboxed process.

  `allowed_modules` are aliased and made available to the evaluated code
  (on top of the built-in safe modules). `timeout_ms` controls the maximum
  execution time (`:infinity` to disable).

  Returns `{:ok, result}` on success, or `{:error, reason}` on validation
  failure, runtime exception, crash, or timeout.
  """
  def execute(code_string, allowed_modules \\ [], timeout_ms \\ 15_000)
      when is_binary(code_string) and is_list(allowed_modules) and
             (is_integer(timeout_ms) or timeout_ms == :infinity) do
    with :ok <- ASTChecker.check(code_string, allowed_modules) do
      code_string
      |> append_aliases(allowed_modules)
      |> eval(timeout_ms)
    end
  end

  defp append_aliases(code_string, allowed_modules) do
    aliases =
      for module <- allowed_modules, into: "" do
        "alias #{module}\n"
      end

    aliases <> code_string
  end

  defp eval(code_string, timeout_ms) do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        result =
          try do
            {:ok, code_string |> Code.eval_string() |> elem(0)}
          rescue
            e -> {:error, e}
          end

        send(parent, {:result, self(), result})
      end)

    receive do
      {:result, ^pid, result} ->
        Process.demonitor(ref, [:flush])
        result

      {:DOWN, ^ref, :process, _pid, reason} ->
        {:error, {:process_crashed, reason}}
    after
      timeout_ms ->
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :kill)
        {:error, :timeout}
    end
  end
end
