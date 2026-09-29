defmodule StealthKitty.HistoryTest do
  use ExUnit.Case, async: true

  alias StealthKitty.History

  test "retains recent turns and tool context after a successful answer" do
    client = StealthKitty.new(max_turns: 3)
    prior = [%{"role" => "user", "content" => "First"}]

    response = %{
      "message" => "Result",
      "tool_call" => "Call",
      "tool_result" => "Data"
    }

    updated = History.record(client, prior, "Next", response)

    assert Enum.map(updated.history, & &1["role"]) == [
             "user",
             "user",
             "assistant"
           ]

    assert List.last(updated.history)["tool_result"] == "Data"
  end

  test "removes old turns before context overflow" do
    old = %{"role" => "user", "content" => String.duplicate("a", 470_000)}
    recent = %{"role" => "assistant", "content" => "recent"}

    assert History.trim([old, recent], "question") == [recent]
  end

  test "rejects invalid turn limits" do
    assert_raise ArgumentError, fn -> StealthKitty.new(max_turns: 0) end
  end
end
