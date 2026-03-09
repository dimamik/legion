defmodule Legion.Sandbox.ASTChecker do
  @moduledoc """
  Static safety check for sandboxed code.

  Parses a code string into an AST and walks every node with `Macro.prewalk/3`,
  rejecting the first violation found. Two categories of violations are checked:

  - **Forbidden forms** — language constructs that could escape the sandbox:
    `alias`, `import`, `require`, `use`, `quote`/`unquote`, `defmodule`,
    `defmacro`, `defprotocol`, `send`, `receive`, `spawn`, `spawn_link`,
    `spawn_monitor`.
  - **Disallowed module calls** — any `Module.function()` or `:erlang_mod.function()`
    call where the module is not in the built-in safe list or the caller-supplied
    allow-list.

  Built-in safe modules: `Kernel`, `String`, `Enum`, `Map`, `MapSet`, `List`,
  `Keyword`, `Tuple`, `Integer`, `Float`, `Atom`, `Regex`, `Range`, `Access`,
  `Stream`, `Date`, `DateTime`, `NaiveDateTime`, `Time`, `:erlang` (with
  dangerous functions blocked), `:math`, `:binary`, `:lists`, `:maps`, `:string`.
  """

  @builtin_allowed [
    Kernel,
    String,
    Enum,
    Map,
    MapSet,
    List,
    Keyword,
    Tuple,
    Integer,
    Float,
    Atom,
    Regex,
    Range,
    Access,
    Stream,
    Date,
    DateTime,
    NaiveDateTime,
    Time,
    :erlang,
    :math,
    :binary,
    :lists,
    :maps,
    :string
  ]

  @forbidden_forms ~w(alias quote unquote defmodule defmacro defprotocol import require use send receive spawn spawn_link spawn_monitor apply)a

  @forbidden_kernel_functions ~w(spawn spawn_link spawn_monitor send apply exit)a

  @forbidden_erlang_functions ~w(spawn spawn_link spawn_monitor send apply exit halt open_port ports port_command)a

  @doc """
  Validates `code_string` against the safety rules.

  `allowed_modules` are accepted in addition to the built-in safe list.
  Both fully-qualified names (`MyApp.Helper`) and their tail aliases (`Helper`)
  are recognised, so code written without aliases will still pass validation
  before `Legion.Sandbox` prepends them for evaluation.

  Must be called **before** alias prepending — `alias` itself is a forbidden form.

  Returns `:ok` or `{:error, reason}` on the first violation (or parse error).
  """
  def check(code_string, allowed_modules) do
    case Code.string_to_quoted(code_string) do
      {:ok, ast} ->
        alias_tails =
          Enum.map(allowed_modules, fn mod ->
            mod |> Module.split() |> List.last() |> then(&Module.concat([&1]))
          end)

        allowed = @builtin_allowed ++ allowed_modules ++ alias_tails
        {_ast, result} = Macro.prewalk(ast, :ok, &check_node(&1, &2, allowed))
        result

      {:error, {_meta, message, token}} ->
        {:error, "Parse error: #{message}#{token}"}
    end
  end

  defp check_node(node, {:error, _} = err, _allowed), do: {node, err}

  # Elixir module calls: ModuleName.function(...)
  defp check_node({{:., _, [{:__aliases__, _, parts}, func]}, _, _} = node, :ok, allowed) do
    module = Module.concat(parts)

    cond do
      module not in allowed ->
        {node, {:error, "Module #{inspect(module)} is not allowed"}}

      module == Kernel and func in @forbidden_kernel_functions ->
        {node, {:error, "Kernel.#{func} is not allowed"}}

      module == Kernel and func == :apply ->
        {node, {:error, "Kernel.apply is not allowed"}}

      true ->
        {node, :ok}
    end
  end

  # Erlang module calls: :atom.function(...)
  defp check_node({{:., _, [mod, func]}, _, _} = node, :ok, allowed) when is_atom(mod) do
    cond do
      mod not in allowed ->
        {node, {:error, "Module #{inspect(mod)} is not allowed"}}

      mod == :erlang and func in @forbidden_erlang_functions ->
        {node, {:error, ":erlang.#{func} is not allowed"}}

      true ->
        {node, :ok}
    end
  end

  # Forbidden special forms
  defp check_node({form, _, _} = node, :ok, _allowed) when form in @forbidden_forms do
    {node, {:error, "#{form} is not allowed"}}
  end

  defp check_node(node, acc, _allowed), do: {node, acc}
end
