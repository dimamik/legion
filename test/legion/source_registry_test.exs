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

  describe "source!/1" do
    test "returns source for a configured module" do
      source = SourceRegistry.source!(Jason)
      assert source =~ "defmodule Jason"
    end

    test "raises for unregistered module" do
      assert_raise RuntimeError, ~r/not registered/, fn ->
        SourceRegistry.source!(Enum)
      end
    end
  end
end
