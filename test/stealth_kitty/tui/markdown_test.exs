defmodule StealthKitty.TUI.MarkdownTest do
  use ExUnit.Case, async: true

  alias StealthKitty.TUI.Markdown
  alias Terra.View

  test "renders headings and inline emphasis with Terra styles" do
    lines = Markdown.render("# Title\n\nA **bold** *word* and `code`.", 40)
    placed = View.place(View.vstack(lines), {0, 0}, {40, 10})

    assert text_of(lines) =~ "Title"
    assert text_of(lines) =~ "A bold word and code."
    refute text_of(lines) =~ "**"
    assert styled?(placed, "b", :bold)
    assert styled?(placed, "w", :italic)
  end

  test "highlights known code and keeps unknown code visible" do
    known = Markdown.render("```elixir\ndef hello, do: :ok\n```", 40)
    unknown = Markdown.render("```mystery\nplain code\n```", 40)
    placed = View.place(View.vstack(known), {0, 0}, {40, 10})

    assert text_of(known) =~ "def hello, do: :ok"
    assert text_of(unknown) =~ "plain code"
    assert styled?(placed, "d", :fg)
  end

  test "renders an incomplete quoted string while code streams" do
    content = """
    Here is an example.

    ```elixir
    def run do
      IO.puts("
    """

    lines = Markdown.render(content, 40)

    assert text_of(lines) =~ "IO.puts(\""
  end

  test "renders every prefix of a streamed code answer" do
    answer = """
    Here is code:

    ```elixir
    def hello(name) do
      IO.puts("Hello, \#{name} 👋")
    end
    ```
    """

    for count <- 1..String.length(answer) do
      answer
      |> String.slice(0, count)
      |> Markdown.render(48)
      |> View.vstack()
      |> View.place({0, 0}, {48, 40})
    end
  end

  test "renders fenced Erlang and JSON code" do
    examples = [
      {"erlang", "hello() -> ok."},
      {"json", ~s({"ok": true, "count": 2})}
    ]

    for {language, source} <- examples do
      markdown = "```#{language}\n#{source}\n```"
      result = markdown |> Markdown.render(40) |> text_of()

      assert result =~ source
    end
  end

  test "wraps wide glyphs within terminal cell width" do
    lines = Markdown.render("**猫猫猫猫猫猫**", 8)

    assert Enum.all?(lines, fn line ->
             {width, _height} = View.measure(line)
             width <= 8
           end)
  end

  test "keeps numbered list prefixes within the cell width" do
    items = Enum.map_join(1..12, "\n", &"#{&1}. example item")
    lines = Markdown.render(items, 12)

    assert Enum.all?(lines, fn line ->
             {width, _height} = View.measure(line)
             width <= 12
           end)
  end

  test "keeps link destinations visible" do
    lines = Markdown.render("Read [the guide](https://example.com).", 70)

    assert text_of(lines) =~ "the guide (https://example.com)"
  end

  test "renders lists, quotes, and tables" do
    content = """
    - first
    - second

    > quoted

    | Name | Value |
    | --- | --- |
    | A | 1 |
    """

    result = content |> Markdown.render(40) |> text_of()

    assert result =~ "• first"
    assert result =~ "│ quoted"
    assert result =~ "Name  │  Value"
  end

  test "keeps nested lists and image references visible" do
    content = """
    - parent
      - child

    ![chart](https://example.com/chart.png)
    """

    result = content |> Markdown.render(70) |> text_of()

    assert result =~ "• parent"
    assert result =~ "  • child"
    assert result =~ "[image: chart]"
    assert result =~ "https://example.com/chart.png"
  end

  defp text_of(lines) do
    Enum.map_join(lines, "\n", fn line ->
      line
      |> View.place({0, 0}, {80, 1})
      |> Enum.map_join(fn {_row, _col, glyph, _style} -> glyph end)
    end)
  end

  defp styled?(placed, glyph, style) do
    Enum.any?(placed, fn {_row, _col, value, styles} ->
      value == glyph and Keyword.has_key?(styles, style)
    end)
  end
end
