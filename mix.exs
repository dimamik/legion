defmodule Legion.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dimamik/legion"

  def project do
    [
      app: :legion,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      # Hex
      package: package(),
      description: """
      Legion is an Elixir-native agentic AI framework.
      """,
      # Docs
      name: "Legion",
      docs: [
        main: "Legion",
        api_reference: false,
        source_ref: "v#{@version}",
        source_url: @source_url,
        formatters: ["html"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Legion.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req_llm, "~> 1.2"},
      {:vault, "~> 0.2"},
      {:telemetry, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Dima Mikielewicz"],
      licenses: ["MIT"],
      links: %{
        Website: "https://dimamik.com",
        Changelog: "#{@source_url}/blob/main/CHANGELOG.md",
        GitHub: @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSE*)
    ]
  end

  defp aliases do
    [
      release: [
        "cmd git tag v#{@version}",
        "cmd git push",
        "cmd git push --tags",
        "hex.publish --yes"
      ],
      "test.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "test --raise"
      ]
    ]
  end
end
