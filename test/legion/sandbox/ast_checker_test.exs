defmodule Legion.Sandbox.ASTCheckerTest do
  use ExUnit.Case

  alias Legion.Sandbox.ASTChecker

  # --- Safe operations ---

  test "literals and arithmetic" do
    assert :ok = ASTChecker.check("1 + 2 * 3", [])
  end

  test "variable assignment and reuse" do
    assert :ok = ASTChecker.check("x = 10\nx * 2", [])
  end

  test "builtin Enum call" do
    assert :ok = ASTChecker.check("Enum.map([1, 2, 3], & &1 + 1)", [])
  end

  test "builtin String call" do
    assert :ok = ASTChecker.check("String.upcase(\"hello\")", [])
  end

  test "builtin Map call" do
    assert :ok = ASTChecker.check("Map.get(%{a: 1}, :a)", [])
  end

  test "erlang math module is allowed" do
    assert :ok = ASTChecker.check(":math.sqrt(4.0)", [])
  end

  test "caller-provided module is allowed" do
    assert :ok = ASTChecker.check("MyTool.run(1)", [MyTool])
  end

  test "caller-provided module not allowed without explicit permission" do
    assert {:error, msg} = ASTChecker.check("MyTool.run(1)", [])
    assert msg =~ "MyTool is not allowed"
  end

  test "nested builtin calls" do
    assert :ok = ASTChecker.check("Enum.map([1, 2], fn x -> Integer.to_string(x) end)", [])
  end

  # --- Disallowed Elixir modules ---

  test "File module is blocked" do
    assert {:error, msg} = ASTChecker.check("File.read!(\"/etc/passwd\")", [])
    assert msg =~ "File"
  end

  test "System module is blocked" do
    assert {:error, msg} = ASTChecker.check("System.halt()", [])
    assert msg =~ "System"
  end

  test "IO module is blocked" do
    assert {:error, msg} = ASTChecker.check("IO.puts(\"hi\")", [])
    assert msg =~ "IO"
  end

  test "Code module is blocked" do
    assert {:error, msg} = ASTChecker.check("Code.eval_string(\"1+1\")", [])
    assert msg =~ "Code"
  end

  test "Process module is blocked" do
    assert {:error, msg} = ASTChecker.check("Process.exit(self(), :kill)", [])
    assert msg =~ "Process"
  end

  # --- Disallowed Erlang modules ---

  test ":os module is blocked" do
    assert {:error, msg} = ASTChecker.check(":os.getenv(\"PATH\")", [])
    assert msg =~ ":os"
  end

  test ":file module is blocked" do
    assert {:error, msg} = ASTChecker.check(":file.read_file(\"/etc/passwd\")", [])
    assert msg =~ ":file"
  end

  test ":io module is blocked" do
    assert {:error, msg} = ASTChecker.check(":io.format(\"hello~n\")", [])
    assert msg =~ ":io"
  end

  # --- Forbidden special forms ---

  test "defmodule is forbidden" do
    assert {:error, msg} = ASTChecker.check("defmodule Foo do end", [])
    assert msg =~ "defmodule"
  end

  test "spawn is forbidden" do
    assert {:error, msg} = ASTChecker.check("spawn(fn -> :ok end)", [])
    assert msg =~ "spawn"
  end

  test "send is forbidden" do
    assert {:error, msg} = ASTChecker.check("send(self(), :hi)", [])
    assert msg =~ "send"
  end

  test "receive is forbidden" do
    code = """
    receive do
      msg -> msg
    end
    """

    assert {:error, msg} = ASTChecker.check(code, [])
    assert msg =~ "receive"
  end

  test "quote is forbidden" do
    assert {:error, msg} = ASTChecker.check("quote do: 1 + 1", [])
    assert msg =~ "quote"
  end

  test "import is forbidden" do
    assert {:error, msg} = ASTChecker.check("import Enum", [])
    assert msg =~ "import"
  end

  test "use is forbidden" do
    assert {:error, msg} = ASTChecker.check("use GenServer", [])
    assert msg =~ "use"
  end

  test "require is forbidden" do
    assert {:error, msg} = ASTChecker.check("require Logger", [])
    assert msg =~ "require"
  end

  test "alias inside code string is forbidden" do
    assert {:error, msg} = ASTChecker.check("alias File, as: String", [])
    assert msg =~ "alias"
  end

  test "aliasing allowed modules works via allowed_modules list" do
    alias Some.Namespace.MyTool
    assert :ok = ASTChecker.check("MyTool.run(1)", [MyTool])
    assert {:error, _} = ASTChecker.check("Other.run(1)", [Some.Namespace.MyTool])
  end

  # --- Forbidden functions on allowed modules ---

  test "Kernel.spawn is forbidden" do
    assert {:error, msg} = ASTChecker.check("Kernel.spawn(fn -> :ok end)", [])
    assert msg =~ "Kernel.spawn"
  end

  test "Kernel.spawn_link is forbidden" do
    assert {:error, msg} = ASTChecker.check("Kernel.spawn_link(fn -> :ok end)", [])
    assert msg =~ "Kernel.spawn_link"
  end

  test "Kernel.send is forbidden" do
    assert {:error, msg} = ASTChecker.check("Kernel.send(self(), :hi)", [])
    assert msg =~ "Kernel.send"
  end

  test "Kernel.apply is forbidden" do
    assert {:error, msg} = ASTChecker.check("Kernel.apply(IO, :puts, [\"hi\"])", [])
    assert msg =~ "Kernel.apply"
  end

  test "Kernel.exit is forbidden" do
    assert {:error, msg} = ASTChecker.check("Kernel.exit(:normal)", [])
    assert msg =~ "Kernel.exit"
  end

  test ":erlang.spawn is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.spawn(fn -> :ok end)", [])
    assert msg =~ ":erlang.spawn"
  end

  test ":erlang.apply is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.apply(IO, :puts, [\"hi\"])", [])
    assert msg =~ ":erlang.apply"
  end

  test ":erlang.get is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.get()", [])
    assert msg =~ ":erlang.get"
  end

  test ":erlang.put is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.put(:key, :value)", [])
    assert msg =~ ":erlang.put"
  end

  test ":erlang.process_flag is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.process_flag(:trap_exit, true)", [])
    assert msg =~ ":erlang.process_flag"
  end

  test ":erlang.list_to_atom is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.list_to_atom(~c\"boom\")", [])
    assert msg =~ ":erlang.list_to_atom"
  end

  test ":erlang.system_info is forbidden" do
    assert {:error, msg} = ASTChecker.check(":erlang.system_info(:process_count)", [])
    assert msg =~ ":erlang.system_info"
  end

  test "__ENV__ is forbidden" do
    assert {:error, msg} = ASTChecker.check("__ENV__", [])
    assert msg =~ "__ENV__"
  end

  # --- Edge cases ---

  test "syntax error returns parse error" do
    assert {:error, msg} = ASTChecker.check("def foo(", [])
    assert msg =~ "Parse error"
  end

  test "disallowed call nested inside allowed call is caught" do
    assert {:error, _} = ASTChecker.check("Enum.map([1], fn _ -> System.halt() end)", [])
  end

  test "multiple violations only returns one error" do
    assert {:error, _} = ASTChecker.check("File.read!(\"x\") || System.halt()", [])
  end
end
