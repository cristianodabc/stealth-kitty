defmodule StealthKitty.TUI.Theme do
  @order ["classic", "ocean", "amber"]

  @themes %{
    "classic" => [accent: :bright_magenta, border: :bright_black],
    "ocean" => [accent: :bright_cyan, border: :bright_black],
    "amber" => [accent: :bright_yellow, border: :bright_black]
  }

  @default "classic"

  def default do
    @default
  end

  def names do
    @order
  end

  def fetch(name) when is_binary(name) do
    Map.fetch(@themes, String.downcase(name))
  end

  def fetch(_name) do
    :error
  end

  def next(name) do
    index = Enum.find_index(@order, &(&1 == name)) || 0
    Enum.at(@order, rem(index + 1, length(@order)))
  end

  def apply(view, name) do
    {:ok, palette} = fetch(name)
    colorize(view, palette)
  end

  defp colorize({:text, value, style}, palette) do
    {:text, value, Terra.Theme.resolve_style(style, palette)}
  end

  defp colorize({:vstack, children, options}, palette) do
    {:vstack, Enum.map(children, &colorize(&1, palette)), options}
  end

  defp colorize({:hstack, children, options}, palette) do
    {:hstack, Enum.map(children, &colorize(&1, palette)), options}
  end

  defp colorize({:box, child, options}, palette) do
    {:box, colorize(child, palette), options}
  end

  defp colorize({:focus, id, child}, palette) do
    {:focus, id, colorize(child, palette)}
  end
end
