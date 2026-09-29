defmodule Lumex.PGP do
  @moduledoc """
  Encrypts a request key to Lumo's pinned OpenPGP subkey.

  The message uses a v3 ECDH session packet and a v1 integrity-protected
  AES-256 data packet. All key material stays in memory.
  """

  alias Lumex.OpenPGP.{ECDH, Message, Packet, PublicKey}

  @type result :: {:ok, binary()} | {:error, :invalid_key}

  @doc "Returns a base64 OpenPGP message containing a 32-byte AES key."
  @spec encrypt_key(binary()) :: result()
  def encrypt_key(key) when byte_size(key) == 32 do
    public_key = PublicKey.load!()
    session_key = :crypto.strong_rand_bytes(32)
    wrapped_key = ECDH.wrap(public_key, session_key)

    packet =
      Packet.encode(1, wrapped_key) <>
        Message.encrypt(session_key, key)

    {:ok, Base.encode64(packet)}
  end

  def encrypt_key(_key) do
    {:error, :invalid_key}
  end
end
