defmodule Lumex.OpenPGP.ECDH do
  @moduledoc "Wraps an AES session key using RFC 6637 Curve25519 ECDH."

  alias Lumex.OpenPGP.{KeyWrap, PublicKey}

  @sender "Anonymous Sender    "

  @doc "Builds the body of a v3 ECDH session-key packet."
  @spec wrap(PublicKey.t(), binary()) :: binary()
  def wrap(%PublicKey{} = recipient, session_key)
      when byte_size(session_key) == 32 do
    {point, secret} = :crypto.generate_key(:ecdh, :x25519)
    shared = :crypto.compute_key(:ecdh, recipient.point, secret, :x25519)
    kek = derive_key(shared, recipient)
    wrapped = KeyWrap.wrap(kek, session_data(session_key))

    <<3, recipient.key_id::binary, 18, 263::16, 0x40, point::binary,
      byte_size(wrapped), wrapped::binary>>
  end

  defp derive_key(shared, recipient) do
    data =
      <<byte_size(recipient.oid), recipient.oid::binary, 18, 3, 1, 8, 7,
        @sender::binary, recipient.fingerprint::binary>>

    digest = :crypto.hash(:sha256, <<1::32, shared::binary, data::binary>>)
    binary_part(digest, 0, 16)
  end

  defp session_data(key) do
    checksum = key |> :binary.bin_to_list() |> Enum.sum() |> rem(65_536)
    <<9, key::binary, checksum::16, 5, 5, 5, 5, 5>>
  end
end
