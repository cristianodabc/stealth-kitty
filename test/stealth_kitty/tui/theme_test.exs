defmodule StealthKitty.TUI.ThemeTest do
  use ExUnit.Case, async: true

  alias StealthKitty.TUI.Theme
  alias StealthKitty.TUI.State
  alias Terra.Renderer
  alias Terra.Renderer.Grid
  alias Terra.View

  test "each named theme paints a distinct accent" do
    accents =
      for name <- Theme.names() do
        assert {:ok, palette} = Theme.fetch(name)

        View.text("✦", fg: :accent)
        |> Renderer.render(width: 2, height: 1, theme: palette)
        |> Grid.get(0, 0)
        |> Map.fetch!(:style)
        |> Keyword.fetch!(:fg)
      end

    assert length(accents) == length(Enum.uniq(accents))
    assert {:ok, _palette} = Theme.fetch(Theme.default())
    assert Theme.fetch("OCEAN") == Theme.fetch("ocean")
  end

  test "invalid theme is rejected before opening the terminal" do
    assert_raise Mix.Error, ~r/Invalid theme: unknown/, fn ->
      Mix.Tasks.StealthKitty.Tui.run(["--theme", "unknown"])
    end
  end

  test "the visible shortcut cycles the rendered accent and survives new chats" do
    machine =
      Terra.Test.start(StealthKitty.TUI,
        app: [theme: "ocean", size: {80, 24}]
      )

    on_exit(fn -> Terra.Test.stop(machine) end)

    state = Terra.Test.state(machine)
    assert state.theme == "ocean"
    assert Terra.Test.render(machine) =~ ~r/THEME\s+\^G\s+✦ Ocean/
    ocean_accent = accent(state)

    Terra.Test.send_keys(machine, {:ctrl, :g})

    state = Terra.Test.state(machine)
    assert state.theme == "amber"
    assert Terra.Test.render(machine) =~ ~r/THEME\s+\^G\s+✦ Amber/
    assert accent(state) != ocean_accent
    state = State.edit(state, "New question", 12)
    assert State.new_conversation(state).theme == "amber"

    short_state = State.resize(state, 40, 14)

    assert short_state
           |> StealthKitty.TUI.view()
           |> Renderer.render(width: 40, height: 14)
           |> Renderer.to_text() =~ ~r/THEME\s+\^G\s+Amber/
  end

  defp accent(state) do
    state
    |> StealthKitty.TUI.view()
    |> View.place({0, 0}, {state.width, state.height})
    |> Enum.find_value(fn {_row, _col, glyph, style} ->
      if glyph == "✦", do: Keyword.get(style, :fg)
    end)
  end
end
