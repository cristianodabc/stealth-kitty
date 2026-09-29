defmodule StealthKitty.OpenPGP.KeyWrap do
  @moduledoc "Implements RFC 3394 AES-128 key wrapping."

  import Bitwise

  @initial <<0xA6, 0xA6, 0xA6, 0xA6, 0xA6, 0xA6, 0xA6, 0xA6>>

  @doc "Wraps 8-byte blocks with a 16-byte AES key."
  @spec wrap(binary(), binary()) :: binary()
  def wrap(kek, data)
      when byte_size(kek) == 16 and byte_size(data) >= 16 and
             rem(byte_size(data), 8) == 0 do
    blocks = for <<block::binary-size(8) <- data>>, do: block

    {a, wrapped} =
      Enum.reduce(0..5, {@initial, blocks}, fn round, state ->
        wrap_round(kek, round, state)
      end)

    IO.iodata_to_binary([a | wrapped])
  end

  defp wrap_round(kek, round, {a, blocks}) do
    count = length(blocks)

    {final_a, reversed} =
      blocks
      |> Enum.with_index(1)
      |> Enum.reduce({a, []}, fn {block, index}, state ->
        step(kek, round * count + index, block, state)
      end)

    {final_a, Enum.reverse(reversed)}
  end

  defp step(kek, counter, block, {a, acc}) do
    <<high::64, low::binary-size(8)>> =
      :crypto.crypto_one_time(:aes_128_ecb, kek, a <> block, true)

    {<<bxor(high, counter)::64>>, [low | acc]}
  end
end
