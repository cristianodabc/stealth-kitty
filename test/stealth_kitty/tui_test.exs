defmodule StealthKitty.TUITest do
  use ExUnit.Case, async: true

  alias StealthKitty.TUI.State

  test "renders chat and toggles web search without a terminal" do
    machine = Terra.Test.start(StealthKitty.TUI)
    on_exit(fn -> Terra.Test.stop(machine) end)

    assert Terra.Test.render(machine) =~ "STEALTH KITTY"
    assert Terra.Test.render(machine) =~ "GUEST"
    assert Terra.Test.render(machine) =~ "WEB OFF"

    Terra.Test.send_keys(machine, {:ctrl, :w})

    assert Terra.Test.render(machine) =~ "WEB ON"
    assert Terra.Test.state(machine).tools == ["web_search"]
  end

  test "keeps authenticated chunks visible and replaces them on completion" do
    client = StealthKitty.new()
    state = client |> State.new() |> State.start_prompt("Hello")
    state = State.append_chunk(state, "First")
    state = State.append_chunk(state, " answer")

    assert List.last(state.messages).content == "First answer"

    state = State.complete(state, %{"message" => "Final answer"}, client)

    refute state.busy
    assert List.last(state.messages).content == "Final answer"
  end

  test "does not clear an in-flight conversation" do
    client = StealthKitty.new()
    state = client |> State.new() |> State.start_prompt("Hello")
    assert StealthKitty.TUI.update({:ctrl, :n}, state) == state
  end

  test "preserves controls changed while a response is in flight" do
    client = StealthKitty.new()
    state = client |> State.new() |> State.start_prompt("Hello")
    state = State.cycle_model(state)
    state = State.toggle_mode(state)
    state = State.toggle_web(state)
    state = State.complete(state, %{"message" => "Hi"}, client)

    assert state.client.model == "lumo-max"
    assert state.client.reasoning_effort == "high"
    assert state.client.web_search
  end

  test "uses the initial terminal size for its layout" do
    {state, _commands} = StealthKitty.TUI.init(size: {48, 16})

    assert state.width == 48
    assert state.height == 16
    assert render(state) =~ "Start a conversation"
  end

  test "starts with the requested model and web search setting" do
    {state, _commands} =
      StealthKitty.TUI.init(
        size: {80, 24},
        model: "lumo-max",
        reasoning_effort: "high",
        web_search: true
      )

    assert state.client.model == "lumo-max"
    assert state.client.reasoning_effort == "high"
    assert state.tools == ["web_search"]
    assert render(state) =~ "WEB ON"

    state = StealthKitty.TUI.update({:ctrl, :w}, state)
    assert state.tools == []
    assert render(state) =~ "WEB OFF"

    state = StealthKitty.TUI.update({:ctrl, :r}, state)
    assert state.client.model == "apertus-15"

    state = StealthKitty.TUI.update({:ctrl, :t}, state)
    assert state.client.reasoning_effort == "none"
  end

  test "keeps the prompt draft while selecting a file" do
    state = StealthKitty.new() |> State.new() |> State.edit("Summarize", 9)
    state = StealthKitty.TUI.update({:ctrl, :u}, state)

    assert state.input_mode == :attachment
    assert state.draft == ""

    state = State.edit(state, "notes.txt", 9)
    state = StealthKitty.TUI.update(:enter, state)

    assert state.input_mode == :prompt
    assert state.attachment == Path.expand("notes.txt")
    assert state.draft == "Summarize"
    assert render(State.resize(state, 80, 24)) =~ "notes.txt"
  end

  test "sends an attached file through the exchange" do
    name = "stealth_kitty-missing-#{System.unique_integer()}"
    path = Path.join(System.tmp_dir!(), name)
    state = %{State.new(StealthKitty.new()) | attachment: path}

    assert {:ok, _pid} =
             StealthKitty.TUI.Exchange.start(self(), state, "Summarize")

    assert_receive {:terra_events, [{:response, {:error, :enoent}}]}
    assert State.start_prompt(state, "Summarize").attachment == nil
  end

  test "shows a useful attachment error" do
    state = State.fail(State.new(StealthKitty.new()), :enoent)
    assert List.last(state.messages).content =~ "could not be found"
  end

  test "keeps the composer inside the frame at common sizes" do
    client = StealthKitty.new()

    for {width, height} <- [{80, 24}, {48, 16}, {40, 14}] do
      state = State.resize(State.new(client), width, height)
      lines = state |> render() |> String.split("\n")

      assert length(lines) == height
      assert Enum.all?(lines, &(String.length(&1) == width))
      assert Enum.any?(lines, &String.contains?(&1, "Ask Lumo"))
    end
  end

  test "keeps every active control visible in a narrow terminal" do
    client =
      StealthKitty.new(
        model: "apertus-15",
        reasoning_effort: "high",
        web_search: true
      )

    state = State.resize(State.new(client), 40, 14)
    frame = render(state)

    assert frame =~ "Apertus"
    assert frame =~ "Think"
    assert frame =~ "On"
    assert frame =~ "⊕"
    assert frame =~ "^U file"
  end

  defp render(state) do
    state
    |> StealthKitty.TUI.view()
    |> Terra.Renderer.render(
      width: state.width,
      height: state.height
    )
    |> Terra.Renderer.to_text()
  end
end
