defmodule StealthKitty.TUI.View do
  @moduledoc """
  Builds the responsive Terra chat view from in-memory state.

  The conversation and composer use fixed heights derived from the terminal
  size, so the input remains visible as the transcript grows.
  """

  import Terra.View

  alias StealthKitty.TUI.State
  alias Terra.Widget

  @doc "Renders the current chat state for Terra."
  @spec render(State.t()) :: Terra.View.t()
  def render(state) do
    box(
      vstack(content(state)),
      border: :rounded,
      padding: [left: 2, right: 2]
    )
  end

  defp content(%{height: height} = state) when height < 16 do
    [
      header(state),
      section(state),
      transcript(state, max(height - 9, 2)),
      status(state),
      composer_heading(state),
      composer(state),
      controls(state),
      footer(state)
    ]
  end

  defp content(state) do
    [
      header(state),
      tagline(state),
      text(""),
      section(state),
      transcript(state, max(state.height - 12, 2)),
      divider(state),
      status(state),
      composer_heading(state),
      composer(state),
      controls(state),
      footer(state)
    ]
  end

  defp header(%{width: width}) when width < 60 do
    text("◆  STEALTH KITTY", fg: :accent, bold: true)
  end

  defp header(state) do
    logo = "◆  STEALTH KITTY"
    mode = session_label(state)
    gap = max(content_width(state) - String.length(logo <> mode), 1)

    hstack([
      text(logo, fg: :accent, bold: true),
      text(String.duplicate(" ", gap)),
      text(mode, dim: true)
    ])
  end

  defp session_label(state) do
    "● #{account_mode(state.client.access_token)}  ·  " <>
      web_mode(state.tools)
  end

  defp account_mode(nil) do
    "GUEST"
  end

  defp account_mode(_token) do
    "ACCOUNT"
  end

  defp web_mode([]) do
    "WEB OFF"
  end

  defp web_mode(_tools) do
    "WEB ON"
  end

  defp tagline(%{width: width} = state) when width < 50 do
    text(StealthKitty.Models.label(state.client.model), dim: true)
  end

  defp tagline(state) do
    label = StealthKitty.Models.label(state.client.model)
    text("#{label}  ·  A quieter place to think and explore.", dim: true)
  end

  defp section(state) do
    heading(state, " CONVERSATION ")
  end

  defp composer_heading(state) do
    heading(state, message_heading(state))
  end

  defp message_heading(%{input_mode: :attachment}) do
    " FILE PATH "
  end

  defp message_heading(%{attachment: nil}) do
    " MESSAGE "
  end

  defp message_heading(state) do
    filename = state.attachment |> Path.basename() |> String.slice(0, 14)
    " MESSAGE · #{filename} "
  end

  defp heading(state, label) do
    remaining = max(content_width(state) - String.length(label), 0)

    hstack([
      text(label, fg: :accent, bold: true),
      text(String.duplicate("─", remaining), dim: true)
    ])
  end

  defp divider(state) do
    text(String.duplicate("─", content_width(state)), dim: true)
  end

  defp transcript(%{messages: []} = state, height) do
    empty_state(state, height)
  end

  defp transcript(state, height) do
    lines = Enum.flat_map(state.messages, &message_lines(&1, state))
    visible = visible_lines(lines, height, state.scroll)
    vstack(visible, height: height)
  end

  defp empty_state(%{width: width} = state, height)
       when width < 60 or height < 8 do
    hero = [
      centered(state, "✦", fg: :accent, bold: true),
      centered(state, "Start a conversation", bold: true),
      centered(state, "Ask Lumo anything.", dim: true)
    ]

    pad_hero(hero, height)
  end

  defp empty_state(state, height) do
    hero = [
      centered(state, "✦", fg: :accent, bold: true),
      text(""),
      centered(state, "A quiet space for your ideas.", bold: true),
      centered(state, "Ask anything. Your conversation starts here.", dim: true)
    ]

    pad_hero(hero, height)
  end

  defp centered(state, label, style) do
    gap = max(div(content_width(state) - Terra.Width.string(label), 2), 0)
    text(String.duplicate(" ", gap) <> label, style)
  end

  defp pad_hero(hero, height) do
    top = max(div(height - length(hero), 2), 0)
    blank = List.duplicate(text(""), top)
    vstack(blank ++ hero, height: height)
  end

  defp message_lines(message, state) do
    label = text(role_label(message.role), role_style(message.role))

    body =
      message.content
      |> wrap(content_width(state) - 2)
      |> Enum.map(&text("  " <> &1))

    [label | body] ++ [text("")]
  end

  defp role_label(:user) do
    "◆ YOU"
  end

  defp role_label(:assistant) do
    "✦ LUMO"
  end

  defp role_label(:error) do
    "! ERROR"
  end

  defp role_style(:user) do
    [fg: :accent, bold: true]
  end

  defp role_style(:assistant) do
    [fg: :bright_white, bold: true]
  end

  defp role_style(:error) do
    [fg: :bright_red, bold: true]
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
    frames = ["◐", "◓", "◑", "◒"]

    hstack([
      Widget.spinner(state.tick, frames: frames, style: [fg: :accent]),
      text("  Lumo is thinking", dim: true)
    ])
  end

  defp status(_state) do
    text("●  Ready for your next question", fg: :green)
  end

  defp composer(state) do
    hstack([
      text(" ❯  ", fg: :accent),
      Widget.input(state.draft,
        cursor: state.cursor,
        focused: not state.busy,
        placeholder: placeholder(state)
      )
    ])
  end

  defp placeholder(%{input_mode: :attachment}) do
    "Enter a local file path…"
  end

  defp placeholder(_state) do
    "Ask Lumo anything…"
  end

  defp controls(%{width: width} = state) when width < 60 do
    model = short_model(state.client.model)
    mode = StealthKitty.AnswerMode.label(state.client.reasoning_effort)
    web = short_web(state.tools)
    text("◇ #{model}  ·  ◷ #{mode}  ·  ◎ #{web}", dim: true)
  end

  defp controls(state) do
    model = StealthKitty.Models.label(state.client.model)
    mode = StealthKitty.AnswerMode.label(state.client.reasoning_effort)
    web = web_mode(state.tools)
    text("◇ #{model}   ◷ #{mode}   ◎ #{web}   ⊕ File", dim: true)
  end

  defp short_model("apertus-15") do
    "Apertus"
  end

  defp short_model("lumo-max") do
    "Max"
  end

  defp short_model(_model) do
    "Lite"
  end

  defp short_web([]) do
    "Off"
  end

  defp short_web(_tools) do
    "On"
  end

  defp footer(%{input_mode: :attachment}) do
    text("↵ attach file   Esc cancel", dim: true)
  end

  defp footer(%{width: width}) when width < 45 do
    text("^R mdl ^T mode ^W web ^U file ^Q", dim: true)
  end

  defp footer(%{width: width}) when width < 70 do
    text("↵ send ^R model ^T mode ^W web ^U file ^Q", dim: true)
  end

  defp footer(_state) do
    text(
      "↵ send  ^R model  ^T mode  ^W web  ^U file  ^N new  ^Q quit",
      dim: true
    )
  end

  defp content_width(state) do
    max(state.width - 6, 12)
  end
end
