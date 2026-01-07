defmodule Legion.Sandbox.Allowlist do
  @moduledoc """
  Behaviour and DSL for defining sandbox allowlists.

  Allowlists control which modules and functions can be called from
  sandboxed code. Use the `allow/2` macro to specify permissions.

  ## Usage

      defmodule MyAllowlist do
        use Legion.Sandbox.Allowlist, extend: Legion.Sandbox.DefaultAllowlist

        # Allow all functions from a module
        allow MyTool, :all

        # Allow only specific functions
        allow AnotherModule, only: [:safe_func, :other_func]

        # Allow all except specific functions
        allow DangerousModule, except: [:dangerous_func]
      end
  """

  @doc """
  Returns the status of a function call.

  Returns `:allowed` if the function can be called, or `:restricted` if blocked.
  """
  @callback fun_status(module :: module(), function :: atom(), arity :: non_neg_integer()) ::
              :allowed | :restricted

  @doc """
  Returns the base allowlist spec (map of module => function permissions).

  Used by `extend:` option to inherit from another allowlist.
  """
  @callback spec() :: map()

  defmacro __using__(opts) do
    extend_module = Keyword.get(opts, :extend)

    quote do
      @behaviour Legion.Sandbox.Allowlist
      import Legion.Sandbox.Allowlist, only: [allow: 2]

      Module.register_attribute(__MODULE__, :allowlist_entries, accumulate: true)
      @extend_module unquote(extend_module)
      @before_compile Legion.Sandbox.Allowlist
    end
  end

  @doc """
  Macro to allow a module's functions in the sandbox.

  ## Options

    * `:all` - Allow all functions from the module
    * `only: [functions]` - Allow only the listed functions
    * `except: [functions]` - Allow all except the listed functions

  ## Examples

      allow Enum, :all
      allow String, except: [:to_atom, :to_existing_atom]
      allow MyTool, only: [:safe_operation]
  """
  defmacro allow(module, opts) do
    quote do
      @allowlist_entries {unquote(module), unquote(opts)}
    end
  end

  @fun_status_quote_ast (quote do
                           @impl Legion.Sandbox.Allowlist
                           def fun_status(module, function, _arity)
                               when is_atom(module) and is_atom(function) do
                             spec()
                             |> Map.get(module)
                             |> evaluate_permission(module, function)
                           end

                           defp evaluate_permission(nil, _module, _function), do: :restricted

                           defp evaluate_permission(:all, module, function),
                             do: allow_if_exported(module, function)

                           defp evaluate_permission([only: functions], module, function) do
                             allow_if(Enum.member?(functions, function), module, function)
                           end

                           defp evaluate_permission([except: functions], module, function) do
                             reject_if(Enum.member?(functions, function), module, function)
                           end

                           defp evaluate_permission(_unsupported, _module, _function),
                             do: :restricted

                           defp allow_if(true, module, function),
                             do: allow_if_exported(module, function)

                           defp allow_if(false, _module, _function), do: :restricted

                           defp reject_if(true, _module, _function), do: :restricted

                           defp reject_if(false, module, function),
                             do: allow_if_exported(module, function)

                           defp allow_if_exported(module, function) do
                             case function_exists?(module, function) do
                               true -> :allowed
                               false -> :restricted
                             end
                           end

                           # Check if function exists with any arity
                           defp function_exists?(module, function) do
                             case Code.ensure_loaded(module) do
                               {:module, _} ->
                                 module.__info__(:functions)
                                 |> Keyword.keys()
                                 |> Enum.member?(function)

                               _ ->
                                 false
                             end
                           end
                         end)

  defmacro __before_compile__(env) do
    entries = Module.get_attribute(env.module, :allowlist_entries) || []
    extend_module = Module.get_attribute(env.module, :extend_module)

    spec_quote = build_spec_quote(entries, extend_module)
    fun_status_quote = @fun_status_quote_ast

    [spec_quote, fun_status_quote]
  end

  defp build_spec_quote(entries, extend_module) do
    base_spec = base_spec_quote(extend_module)

    quote do
      @impl Legion.Sandbox.Allowlist
      def spec do
        base = unquote(base_spec)

        entries =
          unquote(Macro.escape(entries))
          |> Enum.reduce(%{}, fn {module, opts}, acc ->
            Map.put(acc, module, opts)
          end)

        Map.merge(base, entries)
      end
    end
  end

  defp base_spec_quote(nil), do: quote(do: %{})
  defp base_spec_quote(module), do: quote(do: unquote(module).spec())
end
