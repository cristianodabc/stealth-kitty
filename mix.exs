defmodule StealthKitty.MixProject do
  @moduledoc "Mix configuration for Stealth Kitty."

  use Mix.Project

  @doc "Returns the package metadata and dependencies."
  @spec project() :: keyword()
  def project do
    [
      app: :stealth_kitty,
      version: "0.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: [licenses: ["Apache-2.0"]],
      description: "Encrypted Elixir client and terminal UI for Proton Lumo"
    ]
  end

  @doc "Starts cryptography support used by the client."
  @spec application() :: keyword()
  def application do
    [extra_applications: [:crypto]]
  end

  @doc "Runs the quality alias in the test environment."
  @spec cli() :: keyword()
  def cli do
    [preferred_envs: [quality: :test]]
  end

  defp deps do
    [
      {:req, "~> 0.7.4"},
      {:terra, "~> 1.1"},
      {:earmark_parser, "~> 1.4"},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0"},
      {:makeup_erlang, "~> 1.1"},
      {:makeup_json, "~> 1.0"},
      {:makeup_syntect, "~> 0.1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      quality: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "xref graph --format cycles --fail-above 0",
        "deps.unlock --check-unused",
        "credo --strict --min-priority high",
        "test"
      ]
    ]
  end
end
