defmodule StealthKitty.TUI.Syntax do
  @moduledoc """
  Converts Makeup tokens into Terra-compatible styled spans.

  Unknown languages remain readable as plain text.
  """

  alias Makeup.Registry
  alias StealthKitty.TUI.RichText

  @doc "Highlights source for a registered Makeup language."
  @spec spans(binary(), binary()) :: [RichText.span()]
  def spans(source, language) do
    language = String.downcase(language)

    lexer =
      Registry.get_lexer_by_name(language) ||
        Registry.get_lexer_by_extension(language)

    lex(lexer, source)
  end

  defp lex(nil, source) do
    [{source, []}]
  end

  defp lex({lexer, options}, source) do
    source
    |> lexer.lex(options)
    |> Enum.map(&span/1)
  rescue
    _error -> [{source, []}]
  end

  defp span({type, _metadata, value}) do
    {IO.chardata_to_string([value]), style(Atom.to_string(type))}
  end

  defp style("comment" <> _rest) do
    [fg: :bright_black, italic: true]
  end

  defp style("keyword" <> _rest) do
    [fg: :magenta, bold: true]
  end

  defp style("string" <> _rest) do
    [fg: :green]
  end

  defp style("number" <> _rest) do
    [fg: :yellow]
  end

  defp style("name_function" <> _rest) do
    [fg: :cyan]
  end

  defp style("name_class" <> _rest) do
    [fg: :cyan, bold: true]
  end

  defp style("operator" <> _rest) do
    [fg: :magenta]
  end

  defp style(_type) do
    []
  end
end
