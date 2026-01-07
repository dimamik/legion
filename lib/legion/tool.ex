defmodule Legion.Tool do
  @moduledoc """
  Macro for defining Legion tools.

  Tools are regular Elixir modules that expose functions to AI agents.
  When a module uses `Legion.Tool`, it gains introspection capabilities
  that allow Legion to extract documentation and function signatures.

  ## Usage

      defmodule MyApp.HTTPTool do
        @moduledoc "HTTP request utilities"
        use Legion.Tool

        @doc \"\"\"
        Fetches data from the given URL.

        ## Example

            iex> MyApp.HTTPTool.fetch("https://example.com")
            "<html>...</html>"
        \"\"\"
        def fetch(url) do
          # Implementation
        end
      end

  The tool's documentation and function signatures are automatically
  extracted and made available to AI agents through the `__tool_info__/0`
  callback.
  """

  @doc """
  Callback that returns tool metadata for Legion.

  Returns a map containing:
  - `:module` - The tool module name
  - `:moduledoc` - The module's documentation
  - `:functions` - List of public function info with docs and arities
  - `:source_file` - Path to the source file
  """
  @callback __tool_info__() :: %{
              module: module(),
              moduledoc: String.t() | nil,
              functions: [
                %{
                  name: atom(),
                  arity: non_neg_integer(),
                  doc: String.t() | nil,
                  params: [atom()]
                }
              ],
              source_file: String.t() | nil
            }

  @doc """
  Optional callback that returns dynamic documentation based on tool options.

  This is useful for tools like AgentTool that need to include runtime
  configuration (like allowed_agents) in their documentation.

  ## Parameters
    - opts: The tool options map from the agent's `tool_options/1` callback

  ## Returns
    A string to append to the tool's documentation, or nil
  """
  @callback dynamic_doc(opts :: map()) :: String.t() | nil

  @doc """
  Optional callback that returns module aliases to inject into the sandbox.

  This allows tools to expose their configured modules under shorter names.
  For example, AgentTool can expose allowed agents as short aliases.

  ## Parameters
    - opts: The tool options map from the agent's `tool_options/1` callback

  ## Returns
    A list of `{short_name, full_module}` tuples, or empty list
  """
  @callback get_aliases(opts :: map()) :: [{atom(), module()}]

  @doc """
  Optional callback that overrides the tool description in prompts.

  By default, the tool's `@moduledoc` is used as its description.
  Implement this callback to provide a custom description instead.

  ## Returns
    A string description for the tool
  """
  @callback tool_description() :: String.t()

  @optional_callbacks dynamic_doc: 1, get_aliases: 1, tool_description: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour Legion.Tool
      @before_compile Legion.Tool

      # Register a compile-time hook to capture @doc attributes
      Module.register_attribute(__MODULE__, :legion_function_docs, accumulate: false)
      @legion_function_docs %{}

      @on_definition Legion.Tool
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    moduledoc = Module.get_attribute(module, :moduledoc)

    moduledoc_text =
      case moduledoc do
        {_line, doc} when is_binary(doc) -> doc
        _ -> nil
      end

    # Get function definitions at compile time
    functions = extract_functions_at_compile_time(env)

    # Get source file path
    source_file = env.file

    quote do
      @impl Legion.Tool
      def __tool_info__ do
        %{
          module: unquote(module),
          moduledoc: unquote(moduledoc_text),
          functions: unquote(Macro.escape(functions)),
          source_file: unquote(source_file)
        }
      end
    end
  end

  # Internal callbacks that should not appear in tool documentation
  @internal_callbacks [:dynamic_doc, :get_aliases, :tool_description, :__tool_info__]

  defp extract_functions_at_compile_time(env) do
    module = env.module

    # Get all public function definitions
    definitions = Module.definitions_in(module, :def)

    definitions
    |> Enum.reject(fn {name, _arity} ->
      # Exclude private-by-convention, generated, and internal callback functions
      String.starts_with?(Atom.to_string(name), "_") or name in @internal_callbacks
    end)
    |> Enum.map(fn {name, arity} ->
      {doc, params} = get_function_info(module, name, arity)

      %{
        name: name,
        arity: arity,
        doc: doc,
        params: params
      }
    end)
  end

  defp get_function_info(module, name, arity) do
    # Try to get doc and params from the module's accumulated documentation
    case Module.get_attribute(module, :legion_function_docs) do
      nil ->
        {nil, []}

      docs when is_map(docs) ->
        case Map.get(docs, {name, arity}) do
          nil -> {nil, []}
          {doc, params} -> {doc, params}
        end

      _ ->
        {nil, []}
    end
  end

  @doc false
  def __on_definition__(env, :def, name, args, _guards, _body) do
    module = env.module
    arity = length(args)

    # Get current @doc attribute
    doc =
      case Module.get_attribute(module, :doc) do
        {_line, doc} when is_binary(doc) -> doc
        _ -> nil
      end

    # Extract parameter names from args
    params = extract_param_names(args)

    # Update the function docs map
    current_docs = Module.get_attribute(module, :legion_function_docs) || %{}

    # Only update if we have new doc, or if there's no existing entry
    # This handles multiple function clauses where @doc is only on the first clause
    updated_docs =
      case Map.get(current_docs, {name, arity}) do
        nil ->
          # No existing entry, add it
          Map.put(current_docs, {name, arity}, {doc, params})

        {existing_doc, _existing_params} when not is_nil(existing_doc) ->
          # Keep existing doc if it exists, but update params from first clause
          current_docs

        _ ->
          # Existing entry has no doc, update with new doc if available
          Map.put(current_docs, {name, arity}, {doc, params})
      end

    Module.put_attribute(module, :legion_function_docs, updated_docs)
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: :ok

  defp extract_param_names(args) do
    Enum.map(args, fn
      # Simple variable like `x` or `url`
      {name, _meta, nil} when is_atom(name) -> name
      # Pattern match or default arg - try to extract the var name
      {name, _meta, _context} when is_atom(name) -> name
      # Complex pattern - use generic name
      _ -> :arg
    end)
  end
end
