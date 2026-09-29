defmodule StealthKitty.Tools do
  @moduledoc "Builds a tool list for Lumo request options."

  @doc "Adds web search when enabled without duplicating the tool."
  @spec enable_web_search([binary()], boolean()) :: [binary()]
  def enable_web_search(tools, true) do
    Enum.uniq(tools ++ ["web_search"])
  end

  def enable_web_search(tools, false) do
    tools
  end
end
