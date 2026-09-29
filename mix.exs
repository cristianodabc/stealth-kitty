defmodule Lumex.MixProject do
  @moduledoc "Mix configuration for the Lumex library and terminal tools."

  use Mix.Project

  @doc "Returns the package metadata and dependencies."
  @spec project() :: keyword()
  def project do
    [
      app: :lumex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [licenses: ["Apache-2.0"]],
      description: "Encrypted Elixir client and terminal UI for Proton Lumo"
    ]
  end

  @doc "Starts cryptography support used by the client."
  @spec application() :: keyword()
  def application do
    [extra_applications: [:crypto]]
  end

  defp deps do
    [
      {:req, "~> 0.7.4"},
      {:terra, "~> 1.1"}
    ]
  end
end
