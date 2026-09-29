defmodule Lumex.TUI.View do
  @moduledoc """
  Pure Terra view construction for the chat screen.
  Layout adapts to terminal dimensions and keeps the latest turns visible.
  """

  import Terra.View

  alias Terra.Widget
  alias Lumex.TUI.State

  @doc "Renders a chat state as Terra view data."
  @spec render(State.t()) :: Terra.View.t()
  def render(state) do
    box(
      vstack(content(state)),
      title: " Lumo / encrypted conversation ",
      border: :rounded,
      padding: [top: 1, right: 2, bottom: 1, left: 2]
    )
  end

  defp content(state) do
    [
      header(state),
      text(""),
      transcript(state),
      text(""),
      status(state),
      input(state),
      footer()
    ]
  end

  defp header(%{tools: []}) do
    hstack([
      text("◈  LUMEX", fg: :accent, bold: true),
      text("   PRIVATE CHAT", dim: true)
    ])
  end

  defp header(_state) do
    hstack([
      text("◈  LUMEX", fg: :accent, bold: true),
      text("   WEB SEARCH ON", dim: true)
    ])
  end

  defp transcript(state) do
    width = max(state.width - 6, 12)
    height = max(state.height - 9, 4)

    lines =
      state
      |> transcript_lines(width)
      |> visible_lines(height, state.scroll)
      |> Enum.map(&text/1)

    vstack(lines, height: height)
  end

  defp transcript_lines(%{messages: []}, width) do
    lines = [
      "",
      "  Your conversation begins here.",
      "  Ask a question and Lumex will encrypt it before sending.",
      ""
    ]

    Enum.flat_map(lines, &wrap(&1, width))
  end

  defp transcript_lines(state, width) do
    Enum.flat_map(state.messages, &message_lines(&1, width))
  end

  defp message_lines(message, width) do
    [role_label(message.role) | wrap(message.content, width - 2)] ++ [""]
  end

  defp role_label(:user) do
    "YOU"
  end

  defp role_label(:assistant) do
    "LUMO"
  end

  defp role_label(:error) do
    "ERROR"
  end

  defp visible_lines(lines, height, scroll) do
    start = max(length(lines) - height - scroll, 0)
    lines |> Enum.drop(start) |> Enum.take(height)
  end

  defp wrap(content, width) do
    content
    |> String.split("\n", trim: false)
    |> Enum.flat_map(&wrap_line(&1, width))
  end

  defp wrap_line(line, width) do
    line
    |> String.graphemes()
    |> Enum.chunk_every(max(width, 1))
    |> Enum.map(&Enum.join/1)
    |> ensure_line()
  end

  defp ensure_line([]) do
    [""]
  end

  defp ensure_line(lines) do
    lines
  end

  defp status(%{busy: true} = state) do
    hstack([
      Widget.spinner(state.tick, style: [fg: :accent]),
      text("  Lumo is thinking", dim: true)
    ])
  end

  defp status(_state) do
    text("Encrypted with a new key for every request", dim: true)
  end

  defp input(state) do
    hstack([
      text("  ❯ ", fg: :accent),
      Widget.input(state.draft,
        cursor: state.cursor,
        focused: not state.busy,
        placeholder: "Ask Lumo anything…"
      )
    ])
  end

  defp footer do
    text(
      "Enter send   ↑↓ scroll   Ctrl+W web   Ctrl+N new   Ctrl+Q quit",
      dim: true
    )
  end
end
