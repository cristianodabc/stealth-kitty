defmodule StealthKitty.TUI.RichText do
  @moduledoc """
  Wraps styled text in terminal cells and builds Terra lines.
  """

  alias Terra.View
  alias Terra.Width

  @type span :: {binary(), keyword()}

  @doc "Wraps spans to a terminal cell width, retaining their styles."
  @spec wrap([span()], pos_integer()) :: [View.t()]
  def wrap(spans, width) do
    {lines, current, _used} =
      spans
      |> Enum.flat_map(&graphemes/1)
      |> Enum.reduce({[], [], 0}, &place(&1, &2, width))

    [line(current) | lines]
    |> Enum.reverse()
  end

  defp graphemes({content, style}) do
    Enum.map(String.graphemes(content), &{&1, style})
  end

  defp place({"\n", _style}, {lines, current, _used}, _width) do
    {[line(current) | lines], [], 0}
  end

  defp place({glyph, style}, {lines, current, used}, width) do
    size = Width.grapheme(glyph)
    fit({glyph, style}, {lines, current, used}, width, size)
  end

  defp fit({glyph, style}, {lines, current, used}, width, size)
       when used + size > width and current != [] do
    {[line(current) | lines], [{glyph, style}], size}
  end

  defp fit(glyph, {lines, current, used}, _width, size) do
    {lines, [glyph | current], used + size}
  end

  defp line([]) do
    View.text("")
  end

  defp line(reversed) do
    reversed
    |> Enum.reverse()
    |> Enum.chunk_by(fn {_glyph, style} -> style end)
    |> Enum.map(&segment/1)
    |> View.hstack()
  end

  defp segment(segment) do
    {_, style} = hd(segment)
    content = Enum.map_join(segment, "", fn {glyph, _} -> glyph end)
    View.text(content, style)
  end
end
