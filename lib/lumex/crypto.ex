defmodule Lumex.Crypto do
  @moduledoc """
  AES-256-GCM framing for Lumo turns and streamed response chunks.
  The request ID is part of the authenticated context.
  """

  @type decrypt_result :: {:ok, binary()} | {:error, :integrity_error}

  @doc "Encrypts a request turn as base64 nonce, ciphertext, and tag."
  @spec encrypt(binary(), binary(), binary()) :: binary()
  def encrypt(plaintext, key, request_id) do
    nonce = :crypto.strong_rand_bytes(12)
    context = "lumo.request.#{request_id}.turn"
    {ciphertext, tag} = encrypt_aead(plaintext, key, nonce, context)
    Base.encode64(nonce <> ciphertext <> tag)
  end

  @doc """
  Authenticates and decrypts a base64 response chunk. Malformed input,
  a changed tag, or the wrong request ID returns `:integrity_error`.
  """
  @spec decrypt(binary(), binary(), binary()) :: decrypt_result()
  def decrypt(encoded, key, request_id) do
    with {:ok, blob} <- Base.decode64(encoded),
         {:ok, nonce, ciphertext, tag} <- unpack(blob) do
      context = "lumo.response.#{request_id}.chunk"
      decrypt_aead(ciphertext, tag, key, nonce, context)
    else
      _other -> {:error, :integrity_error}
    end
  end

  defp encrypt_aead(plaintext, key, nonce, context) do
    :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      key,
      nonce,
      plaintext,
      context,
      16,
      true
    )
  end

  defp decrypt_aead(ciphertext, tag, key, nonce, context) do
    case :crypto.crypto_one_time_aead(
           :aes_256_gcm,
           key,
           nonce,
           ciphertext,
           context,
           tag,
           false
         ) do
      :error -> {:error, :integrity_error}
      plaintext -> {:ok, plaintext}
    end
  end

  defp unpack(blob) when byte_size(blob) >= 28 do
    <<nonce::binary-size(12), rest::binary>> = blob
    ciphertext_size = byte_size(rest) - 16
    <<ciphertext::binary-size(ciphertext_size), tag::binary-size(16)>> = rest
    {:ok, nonce, ciphertext, tag}
  end

  defp unpack(_blob) do
    {:error, :integrity_error}
  end
end
