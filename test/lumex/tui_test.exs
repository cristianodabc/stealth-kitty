defmodule Lumex.TUITest do
  use ExUnit.Case, async: true

  alias Lumex.TUI.State

  test "renders chat and toggles web search without a terminal" do
    machine = Terra.Test.start(Lumex.TUI)
    on_exit(fn -> Terra.Test.stop(machine) end)

    assert Terra.Test.render(machine) =~ "LUMEX"
    assert Terra.Test.render(machine) =~ "PRIVATE CHAT"

    Terra.Test.send_keys(machine, {:ctrl, :w})

    assert Terra.Test.render(machine) =~ "WEB SEARCH ON"
    assert Terra.Test.state(machine).tools == ["web_search"]
  end

  test "keeps authenticated chunks visible and replaces them on completion" do
    client = Lumex.new()
    state = client |> State.new() |> State.start_prompt("Hello")
    state = State.append_chunk(state, "First")
    state = State.append_chunk(state, " answer")

    assert List.last(state.messages).content == "First answer"

    state = State.complete(state, %{"message" => "Final answer"}, client)

    refute state.busy
    assert List.last(state.messages).content == "Final answer"
  end

  test "does not clear an in-flight conversation" do
    client = Lumex.new()
    state = client |> State.new() |> State.start_prompt("Hello")
    assert Lumex.TUI.update({:ctrl, :n}, state) == state
  end
end
