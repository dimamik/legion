defmodule Legion.ConfigTest do
  use ExUnit.Case, async: true

  alias Legion.Config

  describe "resolve/2" do
    test "returns default config when no overrides" do
      defmodule TestAgentBasic do
        use Legion.AIAgent, tools: []
      end

      config = Config.resolve(TestAgentBasic)

      # Test env overrides from config/test.exs
      assert config.model == "openai:gpt-4o-mini"
      assert config.max_iterations == 5
      assert config.max_retries == 2
    end

    test "merges agent config with defaults" do
      defmodule TestAgentWithConfig do
        use Legion.AIAgent, tools: []

        @impl true
        def config do
          %{max_iterations: 20}
        end
      end

      config = Config.resolve(TestAgentWithConfig)

      assert config.max_iterations == 20
      assert config.max_retries == 2
    end

    test "call opts override agent config" do
      defmodule TestAgentForOverride do
        use Legion.AIAgent, tools: []

        @impl true
        def config do
          %{max_iterations: 20}
        end
      end

      config = Config.resolve(TestAgentForOverride, max_iterations: 3)

      assert config.max_iterations == 3
    end
  end

  describe "defaults/0" do
    test "returns default values" do
      defaults = Config.defaults()

      assert defaults.model == "openai:gpt-4o"
      assert defaults.max_iterations == 10
      assert defaults.max_retries == 3
      assert defaults.timeout == 30_000
      assert defaults.sandbox.timeout == 5_000
    end
  end
end
