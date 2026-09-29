defmodule StealthKitty.AnswerMode do
  @moduledoc "Fast and thinking modes for Lumo generation requests."

  @doc "Checks whether a reasoning effort maps to a Lumo answer mode."
  @spec valid?(binary()) :: boolean()
  def valid?(effort) do
    effort in ["none", "high"]
  end

  @doc "Switches between fast and thinking mode."
  @spec toggle(binary()) :: binary()
  def toggle("high") do
    "none"
  end

  def toggle(_effort) do
    "high"
  end

  @doc "Returns the answer mode name shown in the terminal."
  @spec label(binary()) :: binary()
  def label("high") do
    "Thinking"
  end

  def label(_effort) do
    "Fast"
  end
end
