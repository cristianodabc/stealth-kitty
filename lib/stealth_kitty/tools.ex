defmodule StealthKitty.Tools do
  @moduledoc "Builds a tool list for Lumo request options."

  @choices [
    {"web_search", "Web search"},
    {"weather", "Weather"},
    {"stock", "Stock prices"},
    {"cryptocurrency", "Cryptocurrency"},
    {"proton_info", "Proton information"}
  ]

  @doc "Lists supported built-in tools in display order."
  @spec choices() :: [{binary(), binary()}]
  def choices do
    @choices
  end

  @doc "Checks whether a built-in tool is supported."
  @spec allowed?(binary()) :: boolean()
  def allowed?(name) do
    Enum.any?(@choices, fn {tool, _label} -> tool == name end)
  end

  @doc "Adds web search when enabled without duplicating the tool."
  @spec enable_web_search([binary()], boolean()) :: [binary()]
  def enable_web_search(tools, true) do
    Enum.uniq(tools ++ ["web_search"])
  end

  def enable_web_search(tools, false) do
    tools
  end
end
