defmodule Lumex.OpenPGP.Packet do
  @moduledoc "Encodes and decodes new-format OpenPGP packet headers."

  @type packet :: {non_neg_integer(), binary()}

  @doc "Encodes a packet with a definite-length new-format header."
  @spec encode(non_neg_integer(), binary()) :: binary()
  def encode(tag, body) when tag in 0..63 do
    <<0xC0 + tag>> <> length_bytes(byte_size(body)) <> body
  end

  @doc "Decodes a stream of definite-length new-format packets."
  @spec decode(binary()) :: {:ok, [packet()]} | :error
  def decode(binary) do
    decode(binary, [])
  end

  defp decode(<<>>, packets) do
    {:ok, Enum.reverse(packets)}
  end

  defp decode(<<1::1, 1::1, tag::6, rest::binary>>, packets) do
    with {:ok, size, data} <- read_length(rest),
         <<body::binary-size(size), tail::binary>> <- data do
      decode(tail, [{tag, body} | packets])
    else
      _ -> :error
    end
  end

  defp decode(_binary, _packets) do
    :error
  end

  defp read_length(<<size, rest::binary>>) when size < 192 do
    {:ok, size, rest}
  end

  defp read_length(<<first, second, rest::binary>>)
       when first < 224 do
    {:ok, (first - 192) * 256 + second + 192, rest}
  end

  defp read_length(<<255, size::32, rest::binary>>) do
    {:ok, size, rest}
  end

  defp read_length(_binary) do
    :error
  end

  defp length_bytes(size) when size < 192 do
    <<size>>
  end

  defp length_bytes(size) when size < 8384 do
    value = size - 192
    <<192 + div(value, 256), rem(value, 256)>>
  end

  defp length_bytes(size) do
    <<255, size::32>>
  end
end
