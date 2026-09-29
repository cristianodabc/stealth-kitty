defmodule StealthKitty.TUI.Markdown do
  @moduledoc """
  Renders assistant Markdown as styled Terra lines.

  EarmarkParser supplies the document structure. Makeup colors fenced code,
  and unknown code languages fall back to plain text.
  """

  alias StealthKitty.TUI.RichText
  alias StealthKitty.TUI.Syntax
  alias Terra.View
  alias Terra.Width

  @doc "Renders Markdown within the given terminal cell width."
  @spec render(binary(), pos_integer()) :: [View.t()]
  def render(content, width) do
    content
    |> EarmarkParser.as_ast()
    |> parsed(content, max(width, 1))
  end

  defp parsed({status, nodes, _messages}, _content, width)
       when status in [:ok, :error] do
    nodes
    |> Enum.flat_map(&block(&1, width))
    |> trim_blank()
  end

  defp parsed(_result, content, width) do
    RichText.wrap([{content, []}], width)
  end

  defp block({"pre", _, [{"code", attrs, [source], _}], _}, width) do
    language = attrs |> attribute("class") |> language()
    label = View.text("  #{language}", fg: :accent, bold: true)
    code = code_lines(source, language, width)
    [label | code] ++ [View.text("")]
  end

  defp block({"ul", _, items, _}, width) do
    list_items(items, "•", width)
  end

  defp block({"ol", _, items, _}, width) do
    items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, index} ->
      list_item(item, "#{index}.", width)
    end)
    |> append_blank()
  end

  defp block({"blockquote", _, children, _}, width) do
    children
    |> Enum.flat_map(&block(&1, max(width - 2, 1)))
    |> Enum.map(&View.hstack([View.text("│ ", fg: :accent), &1]))
    |> append_blank()
  end

  defp block({"hr", _, _, _}, width) do
    [View.text(String.duplicate("─", width), dim: true)]
  end

  defp block({"table", _, children, _}, width) do
    children
    |> table_rows()
    |> Enum.flat_map(&RichText.wrap([{&1, []}], width))
    |> append_blank()
  end

  defp block({"h" <> level, _, children, _}, width) do
    style = [fg: :accent, bold: true]
    marker = heading_marker(level)
    spans = [{marker, style} | inline(children, style)]
    RichText.wrap(spans, width) ++ [View.text("")]
  end

  defp block({"p", _, children, _}, width) do
    RichText.wrap(inline(children, []), width) ++ [View.text("")]
  end

  defp block(content, width) when is_binary(content) do
    RichText.wrap([{content, []}], width)
  end

  defp block({_tag, _, children, _}, width) do
    RichText.wrap(inline(children, []), width) ++ [View.text("")]
  end

  defp code_lines(source, language, width) do
    source
    |> Syntax.spans(language)
    |> RichText.wrap(max(width - 2, 1))
    |> Enum.map(&View.hstack([View.text("│ ", fg: :border), &1]))
  end

  defp list_items(items, marker, width) do
    items
    |> Enum.flat_map(&list_item(&1, marker, width))
    |> append_blank()
  end

  defp list_item({"li", _, children, _}, marker, width) do
    prefix = View.text("#{marker} ", fg: :accent)
    body_width = max(width - Width.string("#{marker} "), 1)
    {content, nested} = Enum.split_with(children, &list_content?/1)

    lines =
      content
      |> inline([])
      |> RichText.wrap(body_width)
      |> Enum.map(&View.hstack([prefix, &1]))

    lines ++ nested_lines(nested, width)
  end

  defp nested_lines(nested, width) do
    nested
    |> Enum.flat_map(&block(&1, max(width - 2, 1)))
    |> Enum.map(&View.hstack([View.text("  "), &1]))
  end

  defp list_content?({"ul", _, _, _}) do
    false
  end

  defp list_content?({"ol", _, _, _}) do
    false
  end

  defp list_content?(_node) do
    true
  end

  defp inline(children, style) do
    Enum.flat_map(children, &inline_node(&1, style))
  end

  defp inline_node(content, style) when is_binary(content) do
    [{content, style}]
  end

  defp inline_node({"strong", _, children, _}, style) do
    inline(children, Keyword.put(style, :bold, true))
  end

  defp inline_node({"em", _, children, _}, style) do
    inline(children, Keyword.put(style, :italic, true))
  end

  defp inline_node({"code", _, children, _}, _style) do
    inline(children, fg: :yellow, bg: 236)
  end

  defp inline_node({"a", attrs, children, _}, style) do
    url = attribute(attrs, "href")
    link_style = Keyword.merge(style, fg: :cyan, underline: true)
    inline(children, link_style) ++ link_url(url, children, style)
  end

  defp inline_node({"del", _, children, _}, style) do
    inline(children, Keyword.put(style, :dim, true))
  end

  defp inline_node({"br", _, _, _}, style) do
    [{"\n", style}]
  end

  defp inline_node({"img", attrs, _, _}, style) do
    alt = attribute(attrs, "alt") || "image"
    source = attribute(attrs, "src")
    [{"[image: #{alt}]", style} | link_url(source, [], style)]
  end

  defp inline_node({_tag, _, children, _}, style) do
    inline(children, style)
  end

  defp table_rows(children) do
    Enum.flat_map(children, fn {_section, _, rows, _} ->
      Enum.map(rows, &table_row/1)
    end)
  end

  defp table_row({"tr", _, cells, _}) do
    Enum.map_join(cells, "  │  ", fn {_tag, _, children, _} ->
      children
      |> inline([])
      |> Enum.map_join("", fn {content, _style} -> content end)
    end)
  end

  defp attribute(attributes, name) do
    attributes
    |> List.keyfind(name, 0)
    |> attribute_value()
  end

  defp attribute_value({_name, value}) do
    value
  end

  defp attribute_value(nil) do
    nil
  end

  defp language(nil) do
    "text"
  end

  defp language("") do
    "text"
  end

  defp language(classes) do
    classes
    |> String.split()
    |> List.first()
  end

  defp link_url(nil, _children, _style) do
    []
  end

  defp link_url(url, [url], _style) do
    []
  end

  defp link_url(url, _children, style) do
    [{" (#{url})", Keyword.put(style, :dim, true)}]
  end

  defp heading_marker("1") do
    "✦ "
  end

  defp heading_marker(_level) do
    "◆ "
  end

  defp append_blank(lines) do
    lines ++ [View.text("")]
  end

  defp trim_blank(lines) do
    lines
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == View.text("")))
    |> Enum.reverse()
  end
end
