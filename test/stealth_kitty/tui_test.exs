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

  test "keeps an in-flight conversation when starting another" do
    client = StealthKitty.new()
    state = client |> State.new() |> State.start_prompt("Hello")
    new_state = StealthKitty.TUI.update({:ctrl, :n}, state)

    assert new_state.messages == []

    assert new_state.conversations[state.conversation_id].messages ==
             state.messages

    assert new_state.conversations[state.conversation_id].busy
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

    assert_receive {:terra_events, [{:response, 1, {:error, :enoent}}]}
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

  test "shows active settings in a narrow terminal" do
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
    assert frame =~ "Web On"
    assert frame =~ "^B chats"
  end

  test "renders Markdown answers inside the chat frame" do
    state = State.new(StealthKitty.new())
    message = %{role: :assistant, content: "**Hello** `world`"}
    state = %{state | messages: [message]}
    frame = render(state)

    assert frame =~ "Hello world"
    refute frame =~ "**Hello**"
  end

  test "keeps conversations independent when a reply finishes after switching" do
    client = StealthKitty.new()
    first = client |> State.new() |> State.start_prompt("First question")
    first_id = first.conversation_id

    state = StealthKitty.TUI.update({:ctrl, :n}, first)
    assert state.conversation_id != first_id
    assert state.messages == []

    state = State.edit(state, "Second draft", 12)
    state = StealthKitty.TUI.update({:chunk, first_id, "Partial"}, state)

    state =
      StealthKitty.TUI.update(
        {:response, first_id, {:ok, %{"message" => "First answer"}, client}},
        state
      )

    assert state.draft == "Second draft"
    assert state.messages == []
    assert length(State.sidebar_entries(state)) == 2

    state = State.switch_conversation(state, first_id)

    assert Enum.map(state.messages, & &1.content) == [
             "First question",
             "First answer"
           ]

    refute state.busy

    state = State.switch_conversation(state, first_id + 1)
    assert state.draft == "Second draft"
  end

  test "starting another conversation preserves an unsent draft" do
    state = StealthKitty.new() |> State.new() |> State.edit("Unsent", 6)
    state = StealthKitty.TUI.update({:ctrl, :n}, state)

    assert state.messages == []
    assert state.draft == ""
    assert length(State.sidebar_entries(state)) == 2

    state = State.switch_conversation(state, 1)
    assert state.draft == "Unsent"
  end

  test "sidebar can be hidden and opened as a list on a narrow terminal" do
    {state, _commands} = StealthKitty.TUI.init(size: {110, 24})
    assert render(state) =~ "CONVERSATIONS"

    state = StealthKitty.TUI.update({:ctrl, :b}, state)
    refute render(state) =~ "CONVERSATIONS"

    state = State.resize(state, 40, 14)
    state = StealthKitty.TUI.update({:ctrl, :b}, state)
    assert render(state) =~ "CONVERSATIONS"
    assert render(state) =~ "✦ New conversation"

    state = StealthKitty.TUI.update(:esc, state)
    refute render(state) =~ "CONVERSATIONS"
  end

  test "keeps the cursor and end of a long draft visible" do
    draft = String.duplicate("a", 50) <> " END"

    state =
      StealthKitty.new()
      |> State.new()
      |> State.resize(40, 14)
      |> State.edit(draft, String.length(draft))

    assert render(state) =~ "END"
  end

  test "marks a partial answer incomplete after a failed stream" do
    state = StealthKitty.new() |> State.new() |> State.start_prompt("Hello")
    state = State.append_chunk(state, "Partial answer")
    state = State.fail(state, :incomplete_response)

    assert render(state) =~ "INCOMPLETE"
    assert List.last(state.messages).role == :error
  end

  test "selects a conversation from the wide sidebar" do
    {state, _commands} = StealthKitty.TUI.init(size: {110, 24})
    state = State.start_prompt(state, "First question")
    state = State.new_conversation(state)
    state = State.edit(state, "Unsent draft", 12)

    state = StealthKitty.TUI.update(:tab, state)
    state = StealthKitty.TUI.update(:down, state)
    assert render(state) =~ "✦ First question"
    state = StealthKitty.TUI.update(:enter, state)

    assert state.title == "First question"
    assert Enum.at(state.messages, 0).content == "First question"
    refute state.sidebar_focus

    state = State.switch_conversation(state, 2)
    assert state.draft == "Unsent draft"
  end

  test "keeps the reading position when a streamed answer grows" do
    state = StealthKitty.new() |> State.new() |> State.resize(40, 14)
    state = State.start_prompt(state, "Question")
    state = State.append_chunk(state, String.duplicate("Line of answer\n", 20))

    state = StealthKitty.TUI.update(:up, state)
    before = state |> render() |> String.split("\n") |> Enum.slice(2, 6)
    assert state.scroll != nil

    state = State.append_chunk(state, "One more line\n")
    after_lines = state |> render() |> String.split("\n") |> Enum.slice(2, 6)
    assert after_lines == before
  end

  test "moves by a page and returns to the latest reply" do
    state = StealthKitty.new() |> State.new() |> State.resize(40, 14)
    state = State.start_prompt(state, "Question")
    state = State.append_chunk(state, String.duplicate("Line of answer\n", 30))
    {last, last} = StealthKitty.TUI.View.scroll_position(state)

    state = StealthKitty.TUI.update({:ctrl, :p}, state)
    assert state.scroll == last - StealthKitty.TUI.View.page_size(state)

    state = StealthKitty.TUI.update({:ctrl, :f}, state)
    assert state.scroll == nil

    state = StealthKitty.TUI.update({:ctrl, :p}, state)
    state = StealthKitty.TUI.update({:ctrl, :e}, state)
    assert state.scroll == nil
  end

  test "up on an empty chat still follows new messages" do
    state = StealthKitty.new() |> State.new()
    state = StealthKitty.TUI.update(:up, state)

    assert state.scroll == nil
  end

  test "shows the end of a long Unicode draft" do
    draft = String.duplicate("🙂", 30) <> " END"
    state = StealthKitty.new() |> State.new() |> State.resize(40, 14)
    state = State.edit(state, draft, String.length(draft))

    assert render(state) =~ "END"
  end

  test "shows shortcuts on demand without consuming typed question marks" do
    {state, _commands} = StealthKitty.TUI.init(size: {40, 14})
    assert render(state) =~ "^K keys"

    state = StealthKitty.TUI.update({:ctrl, :k}, state)
    assert render(state) =~ "KEYBOARD SHORTCUTS"
    assert StealthKitty.TUI.update({:char, "a"}, state) == state

    state = StealthKitty.TUI.update(:esc, state)
    state = StealthKitty.TUI.update({:char, "?"}, state)
    assert state.draft == "?"
  end

  test "keeps the sidebar and composer inside wide terminal frames" do
    for width <- [96, 110, 130] do
      {state, _commands} = StealthKitty.TUI.init(size: {width, 24})
      lines = state |> render() |> String.split("\n")

      assert length(lines) == 24
      assert Enum.all?(lines, &(Terra.Width.string(&1) == width))
      assert Enum.any?(lines, &String.contains?(&1, "CONVERSATIONS"))
      assert Enum.any?(lines, &String.contains?(&1, "Ask Lumo"))
    end
  end

  test "marks an inactive conversation's partial answer incomplete" do
    client = StealthKitty.new()
    state = client |> State.new() |> State.start_prompt("First")
    state = State.new_conversation(state)
    state = StealthKitty.TUI.update({:chunk, 1, "Partial"}, state)

    state =
      StealthKitty.TUI.update(
        {:response, 1, {:error, :incomplete_response}},
        state
      )

    assert state.messages == []
    assert state.conversations[1].messages |> Enum.at(1) |> Map.get(:incomplete)
    refute state.conversations[1].busy
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
