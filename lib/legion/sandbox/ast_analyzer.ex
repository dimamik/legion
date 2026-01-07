defmodule Legion.Sandbox.ASTAnalyzer do
  @moduledoc """
  Analyzes AST to detect forbidden module/function calls.

  Walks the AST tree and checks each call against the allowlist.
  Also blocks dangerous patterns that could bypass restrictions.
  """

  # These patterns are always blocked, regardless of allowlist
  @always_blocked_calls [
    # Dynamic dispatch - can't be statically analyzed
    {Kernel, :apply, 2},
    {Kernel, :apply, 3},
    {:erlang, :apply, 2},
    {:erlang, :apply, 3},
    # Code evaluation - could execute arbitrary code
    {Code, :eval_string, 1},
    {Code, :eval_string, 2},
    {Code, :eval_string, 3},
    {Code, :eval_quoted, 1},
    {Code, :eval_quoted, 2},
    {Code, :eval_quoted, 3},
    {Code, :eval_file, 1},
    {Code, :eval_file, 2},
    {Code, :compile_string, 1},
    {Code, :compile_string, 2},
    {Code, :compile_quoted, 1},
    {Code, :compile_quoted, 2},
    # Process spawning
    {Kernel, :spawn, 1},
    {Kernel, :spawn, 3},
    {Kernel, :spawn_link, 1},
    {Kernel, :spawn_link, 3},
    {Kernel, :spawn_monitor, 1},
    {Kernel, :spawn_monitor, 3},
    {:erlang, :spawn, 1},
    {:erlang, :spawn, 2},
    {:erlang, :spawn, 3},
    {:erlang, :spawn, 4},
    {:erlang, :spawn_link, 1},
    {:erlang, :spawn_link, 2},
    {:erlang, :spawn_link, 3},
    {:erlang, :spawn_link, 4},
    {:erlang, :spawn_monitor, 1},
    {:erlang, :spawn_monitor, 2},
    {:erlang, :spawn_monitor, 3},
    {:erlang, :spawn_monitor, 4},
    {:erlang, :spawn_opt, 2},
    {:erlang, :spawn_opt, 3},
    {:erlang, :spawn_opt, 4},
    {:erlang, :spawn_opt, 5},
    # Message passing
    {Kernel, :send, 2},
    {:erlang, :send, 2},
    {:erlang, :send, 3},
    {:erlang, :send_nosuspend, 2},
    {:erlang, :send_nosuspend, 3},
    # Process manipulation (beyond sleep)
    {Process, :exit, 2},
    {Process, :flag, 2},
    {Process, :flag, 3},
    {Process, :link, 1},
    {Process, :unlink, 1},
    {Process, :register, 2},
    {Process, :unregister, 1},
    {Process, :whereis, 1},
    {:erlang, :exit, 1},
    {:erlang, :exit, 2},
    {:erlang, :halt, 0},
    {:erlang, :halt, 1},
    {:erlang, :halt, 2}
  ]

  # These modules are entirely blocked
  @blocked_modules [
    System,
    File,
    Path,
    Port,
    Node,
    Agent,
    GenServer,
    Supervisor,
    Task,
    Registry,
    DynamicSupervisor,
    :file,
    :filelib,
    :filename,
    :os,
    :net,
    :net_adm,
    :net_kernel,
    :gen_tcp,
    :gen_udp,
    :gen_sctp,
    :ssl,
    :httpc,
    :httpd,
    :ssh,
    :erl_eval,
    :erl_parse,
    :compile
  ]

  # These special forms / local calls are blocked
  @blocked_special_forms [:receive, :import, :require, :alias]

  # These definition forms are blocked
  @blocked_definitions [
    :defmodule,
    :def,
    :defp,
    :defmacro,
    :defmacrop,
    :defstruct,
    :defprotocol,
    :defimpl
  ]

  @doc """
  Analyzes the AST and returns :ok if safe, or {:error, reason} if forbidden calls are found.
  """
  @spec analyze(Macro.t(), module(), keyword()) :: :ok | {:error, map()}
  def analyze(ast, allowlist_module, opts \\ []) do
    aliases = Keyword.get(opts, :aliases, []) |> Map.new()

    case do_analyze(ast, allowlist_module, aliases, []) do
      [] -> :ok
      [error | _] -> {:error, error}
    end
  end

  defp do_analyze(ast, allowlist_module, aliases, errors) do
    {_ast, errors} =
      Macro.prewalk(ast, errors, fn node, acc ->
        case check_node(node, allowlist_module, aliases) do
          :ok -> {node, acc}
          {:error, reason} -> {node, [reason | acc]}
        end
      end)

    Enum.reverse(errors)
  end

  # Check remote calls: Module.function(args)
  defp check_node({{:., _meta, [module, function]}, _call_meta, args}, allowlist_module, aliases)
       when is_atom(module) and is_atom(function) do
    module = Map.get(aliases, module, module)
    arity = length(args)
    check_mfa(module, function, arity, allowlist_module)
  end

  # Check remote calls with aliased modules: {:__aliases__, _, [:Module]}
  defp check_node(
         {{:., _meta, [{:__aliases__, _, module_parts}, function]}, _call_meta, args},
         allowlist_module,
         aliases
       )
       when is_atom(function) do
    module = Module.concat(module_parts)
    module = Map.get(aliases, module, module)
    arity = length(args)
    check_mfa(module, function, arity, allowlist_module)
  end

  # Check function captures: &Module.function/arity
  defp check_node(
         {:&, _meta, [{:/, _, [{{:., _, [module, function]}, _, _}, arity]}]},
         allowlist_module,
         aliases
       )
       when is_atom(module) and is_atom(function) and is_integer(arity) do
    module = Map.get(aliases, module, module)
    check_mfa(module, function, arity, allowlist_module)
  end

  # Check function captures with aliased modules
  defp check_node(
         {:&, _meta,
          [{:/, _, [{{:., _, [{:__aliases__, _, module_parts}, function]}, _, _}, arity]}]},
         allowlist_module,
         aliases
       )
       when is_atom(function) and is_integer(arity) do
    module = Module.concat(module_parts)
    module = Map.get(aliases, module, module)
    check_mfa(module, function, arity, allowlist_module)
  end

  # Check local function captures: &function/arity (implicitly Kernel)
  # These captures can bypass the sandbox if they refer to dangerous Kernel functions
  defp check_node(
         {:&, _meta, [{:/, _, [{function, _, _local_context}, arity]}]},
         allowlist_module,
         _aliases
       )
       when is_atom(function) and is_integer(arity) do
    # Local captures implicitly refer to Kernel module
    check_mfa(Kernel, function, arity, allowlist_module)
  end

  # Block receive special form
  defp check_node({:receive, _meta, _args}, _allowlist_module, _aliases) do
    {:error, %{type: :restricted, message: "receive blocks are not allowed in sandbox"}}
  end

  # Block import/require/alias
  defp check_node({form, _meta, _args}, _allowlist_module, _aliases)
       when form in @blocked_special_forms do
    {:error, %{type: :restricted, message: "#{form} is not allowed in sandbox"}}
  end

  # Block definition forms at top level
  defp check_node({form, _meta, _args}, _allowlist_module, _aliases)
       when form in @blocked_definitions do
    {:error, %{type: :restricted, message: "#{form} is not allowed in sandbox"}}
  end

  # Block local calls to dangerous Kernel functions
  defp check_node({:spawn, _meta, args}, _allowlist_module, _aliases) when is_list(args) do
    {:error, %{type: :restricted, message: "spawn is not allowed in sandbox"}}
  end

  defp check_node({:spawn_link, _meta, args}, _allowlist_module, _aliases) when is_list(args) do
    {:error, %{type: :restricted, message: "spawn_link is not allowed in sandbox"}}
  end

  defp check_node({:spawn_monitor, _meta, args}, _allowlist_module, _aliases)
       when is_list(args) do
    {:error, %{type: :restricted, message: "spawn_monitor is not allowed in sandbox"}}
  end

  defp check_node({:send, _meta, args}, _allowlist_module, _aliases)
       when is_list(args) and length(args) == 2 do
    {:error, %{type: :restricted, message: "send is not allowed in sandbox"}}
  end

  defp check_node({:apply, _meta, args}, _allowlist_module, _aliases)
       when is_list(args) and length(args) in [2, 3] do
    {:error, %{type: :restricted, message: "apply is not allowed in sandbox"}}
  end

  defp check_node({:exit, _meta, args}, _allowlist_module, _aliases)
       when is_list(args) and length(args) == 1 do
    {:error, %{type: :restricted, message: "exit is not allowed in sandbox"}}
  end

  # All other nodes are OK at AST level
  defp check_node(_node, _allowlist_module, _aliases) do
    :ok
  end

  defp check_mfa(module, function, arity, allowlist_module) do
    cond do
      # Check always-blocked calls first
      {module, function, arity} in @always_blocked_calls ->
        {:error,
         %{
           type: :restricted,
           message: "function #{inspect(module)}.#{function}/#{arity} is restricted"
         }}

      # Check blocked modules
      module in @blocked_modules ->
        {:error,
         %{
           type: :restricted,
           message: "module #{inspect(module)} is restricted"
         }}

      # Check allowlist
      allowlist_module.fun_status(module, function, arity) == :allowed ->
        :ok

      true ->
        {:error,
         %{
           type: :restricted,
           message: "function #{inspect(module)}.#{function}/#{arity} is restricted"
         }}
    end
  end
end
