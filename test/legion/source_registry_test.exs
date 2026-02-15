defmodule Legion.SourceRegistryTest do
  use ExUnit.Case

  alias Legion.SourceRegistry

  describe "source/1 for external modules" do
    test "returns source for a configured external module" do
      assert {:ok, source} = SourceRegistry.source(Jason)
      assert source =~ "defmodule Jason"
    end
  end

  describe "source/1 for unknown modules" do
    test "returns error for unregistered module" do
      assert {:error, :not_registered} = SourceRegistry.source(Enum)
    end
  end
end
