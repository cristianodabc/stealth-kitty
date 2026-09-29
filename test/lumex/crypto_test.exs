defmodule Lumex.CryptoTest do
  use ExUnit.Case, async: true

  alias Lumex.{Crypto, PGP}

  test "decrypts a valid response chunk" do
    key = :crypto.strong_rand_bytes(32)
    id = Lumex.ID.uuid4()
    encoded = response_chunk("hello", key, id)

    assert {:ok, "hello"} = Crypto.decrypt(encoded, key, id)
  end

  test "rejects a changed tag and a different request ID" do
    key = :crypto.strong_rand_bytes(32)
    id = Lumex.ID.uuid4()
    encoded = response_chunk("hello", key, id)

    assert {:error, :integrity_error} = Crypto.decrypt(tamper(encoded), key, id)
    assert {:error, :integrity_error} = Crypto.decrypt(encoded, key, "other")
    assert {:error, :integrity_error} = Crypto.decrypt("bad", key, id)
  end

  test "wraps a fresh AES key in an OpenPGP message" do
    key = :crypto.strong_rand_bytes(32)

    assert {:ok, encoded} = PGP.encrypt_key(key)
    assert {:ok, packet} = Base.decode64(encoded)
    assert byte_size(packet) > 80
    assert {:error, :invalid_key} = PGP.encrypt_key(<<1, 2>>)
  end

  defp response_chunk(plaintext, key, id) do
    nonce = :crypto.strong_rand_bytes(12)
    context = "lumo.response.#{id}.chunk"

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        key,
        nonce,
        plaintext,
        context,
        16,
        true
      )

    Base.encode64(nonce <> ciphertext <> tag)
  end

  defp tamper(encoded) do
    {:ok, blob} = Base.decode64(encoded)
    prefix_size = byte_size(blob) - 1
    <<prefix::binary-size(prefix_size), last>> = blob
    Base.encode64(prefix <> <<Bitwise.bxor(last, 1)>>)
  end
end
