defmodule Spect.MixProject do
  use Mix.Project

  # project properties
  def project do
    [
      app: :spect,
      name: "Spect",
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Type specification extensions for Elixir.",
      package: package(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test],
      dialyzer: [
        ignore_warnings: ".dialyzerignore",
        plt_add_deps: :transitive
      ],
      docs: [extras: ["README.md"]]
    ]
  end

  # hex package configuration
  defp package do
    [
      files: ["mix.exs", "README.md", "lib"],
      maintainers: ["Brent M. Spell"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/pylon/spect",
        "Docs" => "http://hexdocs.pm/spect/"
      }
    ]
  end

  # project dependencies
  defp deps do
    [
      {:excoveralls, "~> 0.8", only: :test},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:benchee, "~> 0.9", only: :dev, runtime: false},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false}
    ]
  end

  # compilation paths
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
