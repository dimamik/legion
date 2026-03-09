defmodule Legion.AgentTest do
  use ExUnit.Case, async: true

  defmodule MinimalAgent do
    @moduledoc "A minimal agent with no overrides."
    use Legion.Agent
  end

  defmodule PartialOverrideAgent do
    @moduledoc "Agent that overrides tool_config for one tool only."
    use Legion.Agent

    def tools, do: [Legion.Tools.AgentTool]
    def tool_config(Legion.Tools.AgentTool), do: [agents: [MinimalAgent]]
  end

  describe "tool_config/1" do
    test "returns [] for any argument without explicit override" do
      assert MinimalAgent.tool_config(:anything) == []
      assert MinimalAgent.tool_config(Legion.Tools.AgentTool) == []
    end

    test "partial override falls back to [] for non-matching tools" do
      assert PartialOverrideAgent.tool_config(Legion.Tools.AgentTool) == [agents: [MinimalAgent]]
      assert PartialOverrideAgent.tool_config(:other) == []
      assert PartialOverrideAgent.tool_config(SomeModule) == []
    end
  end

  describe "defaults" do
    test "moduledoc returns @moduledoc" do
      assert MinimalAgent.moduledoc() == "A minimal agent with no overrides."
    end

    test "tools defaults to []" do
      assert MinimalAgent.tools() == []
    end

    test "output_schema defaults to string type" do
      assert MinimalAgent.output_schema() == %{"type" => "string"}
    end
  end
end
