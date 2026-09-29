defmodule Lumex.OpenPGP.Message do
  @moduledoc "Encrypts binary literal data in an OpenPGP SEIPD v1 packet."

  alias Lumex.OpenPGP.Packet

  @doc "Returns an integrity-protected AES-256 OpenPGP data packet."
  @spec encrypt(binary(), binary()) :: binary()
  def encrypt(session_key, data) when byte_size(session_key) == 32 do
    prefix = random_prefix()
    literal = Packet.encode(11, <<?b, 0, 0::32, data::binary>>)
    contents = prefix <> literal <> <<0xD3, 0x14>>
    mdc = :crypto.hash(:sha, contents)

    ciphertext =
      :crypto.crypto_one_time(
        :aes_256_cfb128,
        session_key,
        <<0::128>>,
        contents <> mdc,
        true
      )

    Packet.encode(18, <<1, ciphertext::binary>>)
  end

  defp random_prefix do
    random = :crypto.strong_rand_bytes(16)
    random <> binary_part(random, 14, 2)
  end
end
