defmodule StealthKitty.ToolsTest do
  use ExUnit.Case, async: true

  alias StealthKitty.Tools

  test "adds web search once when enabled" do
    assert Tools.enable_web_search([], true) == ["web_search"]

    assert Tools.enable_web_search(["weather", "web_search"], true) ==
             ["weather", "web_search"]
  end

  test "leaves requested tools alone when disabled" do
    assert Tools.enable_web_search(["weather"], false) == ["weather"]
  end
end
