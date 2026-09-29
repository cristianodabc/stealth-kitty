defmodule StealthKitty.TUI.View do
  @moduledoc """
  Builds the responsive Terra chat view from in-memory state.

  The conversation and composer use fixed heights derived from the terminal
  size, so the input remains visible as the transcript grows.
  """

  import Terra.View

  alias StealthKitty.TUI.State
  alias StealthKitty.TUI.Markdown
  alias Terra.Widget

  @sidebar_width 24
  @sidebar_min_width 96

  @doc "Renders the current chat state for Terra."
  @spec render(State.t()) :: Terra.View.t()
  def render(state) do
    body =
      cond do
        state.help_visible ->
          help_page(state)

        narrow_sidebar?(state) ->
          sidebar_page(state)

        wide_sidebar?(state) ->
          separator = List.duplicate(text("│", fg: :border), state.height - 2)

          hstack([
            sidebar(state),
            vstack(separator),
            text(" "),
            vstack(content(state))
          ])

        true ->
          vstack(content(state))
      end

    box(
      body,
      border: :rounded,
      padding: [left: 2, right: 2]
    )
  end

  @doc "Returns the first visible transcript line and the last possible start."
  @spec scroll_position(State.t()) :: {non_neg_integer(), non_neg_integer()}
  def scroll_position(state) do
    last = max(length(transcript_lines(state)) - transcript_height(state), 0)
    first = if is_nil(state.scroll), do: last, else: min(state.scroll, last)
    {first, last}
  end

  @doc "Returns the number of lines moved by a page navigation key."
  @spec page_size(State.t()) :: pos_integer()
  def page_size(state) do
    max(transcript_height(state) - 1, 1)
  end

  defp content(%{height: height} = state) when height < 16 do
    [
      header(state),
      transcript(state, transcript_height(state)),
      status(state),
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
      transcript(state, transcript_height(state)),
      divider(state),
      status(state),
      composer_heading(state),
      composer(state),
      controls(state),
      footer(state)
    ]
  end

  defp transcript_height(%{height: height}) when height < 16 do
    max(height - 8, 2)
  end

  defp transcript_height(state) do
    max(state.height - 14, 2)
  end

  defp wide_sidebar?(state) do
    state.sidebar_visible and state.width >= @sidebar_min_width
  end

  defp narrow_sidebar?(state) do
    state.sidebar_visible and state.width < @sidebar_min_width
  end

  defp sidebar(state) do
    rows =
      [
        text("CONVERSATIONS", fg: :accent, bold: true),
        text(String.duplicate("─", 20), dim: true)
      ] ++
        sidebar_rows(state, 20, max(state.height - 8, 1)) ++
        [
          text(""),
          text("^N new  ^B hide", dim: true),
          text("Tab select", dim: true)
        ]

    vstack(rows, width: @sidebar_width, height: state.height - 2)
  end

  defp sidebar_page(state) do
    width = content_width(state)

    rows =
      [
        text("✦  STEALTH KITTY", fg: :accent, bold: true),
        text(""),
        text("CONVERSATIONS", fg: :accent, bold: true),
        text(String.duplicate("─", width), dim: true)
      ] ++
        sidebar_rows(state, width, max(state.height - 8, 1)) ++
        [
          text(""),
          text("↑↓ choose  ↵ open  Esc back", dim: true)
        ]

    vstack(rows, height: state.height - 2)
  end

  defp help_page(state) do
    rows = [
      text("✦  STEALTH KITTY", fg: :accent, bold: true),
      text(""),
      text("KEYBOARD SHORTCUTS", fg: :accent, bold: true),
      text(String.duplicate("─", max(state.width - 6, 12)), dim: true),
      text("↵ send     ^N new conversation"),
      text("^R model   ^T Fast / Thinking"),
      text("^W web     ^U attach file"),
      text("^B chats   Tab focus sidebar"),
      text("↑↓ lines    ^P/^F pages"),
      text("^E latest   Esc back or quit"),
      text("^Q quit     ^K close guide", fg: :accent)
    ]

    vstack(rows, height: state.height - 2)
  end

  defp sidebar_rows(state, width, slots) do
    entries = State.sidebar_entries(state)
    first = max(state.sidebar_selection - slots + 1, 0)

    rows =
      entries
      |> Enum.with_index()
      |> Enum.drop(first)
      |> Enum.take(slots)
      |> Enum.map(fn {entry, index} ->
        sidebar_row(entry, index, state, width)
      end)

    rows ++ List.duplicate(text(""), slots - length(rows))
  end

  defp sidebar_row(entry, index, state, width) do
    marker =
      cond do
        index == state.sidebar_selection and state.sidebar_focus -> "✦ "
        entry.busy -> "◐ "
        entry.active -> "● "
        true -> "  "
      end

    title = fit(entry.title, max(width - 2, 1))

    style =
      if entry.active or index == state.sidebar_selection,
        do: [fg: :accent],
        else: []

    text("#{marker}#{title}", style)
  end

  defp header(%{width: width}) when width < 60 do
    text("✦  STEALTH KITTY", fg: :accent, bold: true)
  end

  defp header(state) do
    logo = "✦  STEALTH KITTY"
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
    lines = transcript_lines(state)
    visible = visible_lines(lines, height, state.scroll)
    vstack(visible, height: height)
  end

  defp transcript_lines(state) do
    Enum.flat_map(state.messages, &message_lines(&1, state))
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
      centered(state, "  ✧  ", fg: :accent),
      centered(state, "✧ ✦ ✧", fg: :accent, bold: true),
      centered(state, "  ✧  ", fg: :accent),
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

  defp message_lines(%{role: :assistant} = message, state) do
    label =
      if Map.get(message, :incomplete) do
        text("✦ LUMO · INCOMPLETE", fg: :bright_red, bold: true)
      else
        text(role_label(:assistant), role_style(:assistant))
      end

    body =
      message.content
      |> Markdown.render(content_width(state) - 2)
      |> Enum.map(&hstack([text("  "), &1]))

    [label | body] ++ [text("")]
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
    last = max(length(lines) - height, 0)
    start = if is_nil(scroll), do: last, else: min(scroll, last)
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

  defp status(%{busy: true, scroll: scroll} = state) when not is_nil(scroll) do
    {first, last} = scroll_position(state)
    percent = if last == 0, do: 100, else: round(first * 100 / last)
    busy_status(state, "  Lumo is thinking · History #{percent}%")
  end

  defp status(%{busy: true} = state) do
    busy_status(state, "  Lumo is thinking")
  end

  defp status(%{scroll: nil}) do
    text("●  Ready for your next question", fg: :green)
  end

  defp status(state) do
    {first, last} = scroll_position(state)

    if last > 0 do
      percent = round(first * 100 / last)

      text(fit("↑  History #{percent}% · ↓ latest", content_width(state)),
        fg: :accent
      )
    else
      text("●  Ready for your next question", fg: :green)
    end
  end

  defp busy_status(state, label) do
    frames = ["◐", "◓", "◑", "◒"]

    hstack([
      Widget.spinner(state.tick, frames: frames, style: [fg: :accent]),
      text(fit(label, content_width(state) - 1), dim: true)
    ])
  end

  defp composer(state) do
    width = max(content_width(state) - 6, 1)

    {value, cursor, left?, right?} =
      input_window(state.draft, state.cursor, width)

    hstack([
      text(" ❯  ", fg: :accent),
      text(if(left?, do: "‹", else: " "), dim: true),
      Widget.input(value,
        cursor: cursor,
        focused: not state.busy,
        placeholder: fit(placeholder(state), width)
      ),
      text(if(right?, do: "›", else: " "), dim: true)
    ])
  end

  defp input_window(value, cursor, width) do
    graphemes = String.graphemes(value)
    cursor = min(cursor, length(graphemes))
    prefix = Enum.take(graphemes, cursor)
    start = cursor - length(take_width(Enum.reverse(prefix), width - 1))
    visible = graphemes |> Enum.drop(start) |> take_width(width - 1)

    {Enum.join(visible), cursor - start, start > 0,
     start + length(visible) < length(graphemes)}
  end

  defp take_width(graphemes, width) do
    {taken, _used} =
      Enum.reduce_while(graphemes, {[], 0}, fn grapheme, {acc, used} ->
        size = Terra.Width.grapheme(grapheme)

        if used + size <= width do
          {:cont, {[grapheme | acc], used + size}}
        else
          {:halt, {acc, used}}
        end
      end)

    Enum.reverse(taken)
  end

  defp fit(value, width) do
    value
    |> String.graphemes()
    |> take_width(width)
    |> Enum.join()
  end

  defp placeholder(%{input_mode: :attachment}) do
    "Enter a local file path…"
  end

  defp placeholder(_state) do
    "Ask Lumo anything…"
  end

  defp controls(%{width: width} = state) when width < 60 do
    model = short_model(state.client.model)
    mode = short_mode(state.client.reasoning_effort)
    web = short_web(state.tools)

    first =
      chip_row([
        chip(" ◇ #{model} ^R ", :selected),
        chip(" ◷ #{mode} ^T ", thinking?(state))
      ])

    second =
      chip_row([
        chip(" ◎ Web #{web} ^W ", web?(state)),
        chip(file_chip(state, 8), attached?(state))
      ])

    vstack([first, second])
  end

  defp controls(state) do
    model = StealthKitty.Models.label(state.client.model)
    mode = StealthKitty.AnswerMode.label(state.client.reasoning_effort)
    web = short_web(state.tools)

    first =
      chip_row([
        chip(" ◇ #{model} ^R ", :selected),
        chip(" ◷ #{mode} ^T ", thinking?(state))
      ])

    second =
      chip_row([
        chip(" ◎ Web #{web} ^W ", web?(state)),
        chip(file_chip(state, 14), attached?(state))
      ])

    vstack([first, text(""), second])
  end

  defp chip_row(chips) do
    chips
    |> Enum.intersperse(text("  "))
    |> hstack()
  end

  defp chip(label, :selected) do
    text(label, fg: :accent, bg: 236, bold: true)
  end

  defp chip(label, true) do
    text(label, fg: :bright_white, bg: 54, bold: true)
  end

  defp chip(label, false) do
    text(label, fg: :bright_white, bg: 236)
  end

  defp file_chip(%{attachment: nil}, _limit) do
    " ⊕ File ^U "
  end

  defp file_chip(state, limit) do
    filename = state.attachment |> Path.basename() |> fit(limit)
    " ⊕ #{filename} ^U "
  end

  defp thinking?(state) do
    state.client.reasoning_effort == "high"
  end

  defp web?(state) do
    state.tools != []
  end

  defp attached?(state) do
    state.attachment != nil
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

  defp short_mode("high") do
    "Think"
  end

  defp short_mode(_effort) do
    "Fast"
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

  defp footer(state) do
    width = content_width(state)

    content =
      cond do
        width < 45 -> "↵ send  ^K keys  ^B chats"
        true -> "↵ send  ^K keys  ^B chats  ^N new  ^Q quit"
      end

    text(fit(content, width), dim: true)
  end

  defp content_width(state) do
    sidebar_space = if wide_sidebar?(state), do: @sidebar_width + 2, else: 0
    max(state.width - 6 - sidebar_space, 12)
  end
end
