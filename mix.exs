defmodule Legion.MixProject do
  use Mix.Project

  def project do
    [
      app: :legion,
      version: "0.2.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Legion",
      source_url: "https://github.com/dimamik/legion",
      docs: docs(),
      aliases: aliases()
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req_llm, "~> 1.2"},
      {:vault, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mimic, "~> 1.7", only: :test}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "credo --strict",
        "sobelow --exit --skip",
        "test --exclude integration"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Core: [Legion, Legion.Agent, Legion.Tool],
        Runtime: [Legion.AgentServer, Legion.Executor, ~r/^Legion\.Sandbox/],
        Tools: [~r/^Legion\.Tools\./],
        Internals: [Legion.AgentPrompt, Legion.SourceRegistry, Legion.Telemetry]
      ]
    ]
  end
end
