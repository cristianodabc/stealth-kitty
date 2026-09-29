defmodule Lumex.OpenPGPTest do
  use ExUnit.Case, async: true

  alias Lumex.OpenPGP.{KeyWrap, Message, Packet, PublicKey}

  test "loads Lumo's pinned ECDH subkey" do
    key = PublicKey.load!()

    assert Base.encode16(key.key_id) == "E7DF128A8FC5DE04"
    assert byte_size(key.point) == 32
    assert byte_size(key.fingerprint) == 20
  end

  test "encodes packet lengths at each format boundary" do
    for size <- [0, 191, 192, 8_383, 8_384] do
      body = :binary.copy(<<0x42>>, size)

      assert {:ok, [{11, ^body}]} =
               11 |> Packet.encode(body) |> Packet.decode()
    end
  end

  test "wraps the RFC 3394 AES-128 test vector" do
    kek = Base.decode16!("000102030405060708090A0B0C0D0E0F")
    data = Base.decode16!("00112233445566778899AABBCCDDEEFF")

    expected =
      Base.decode16!("1FA68B0A8112B447AEF34BD8FB5A7B829D3E862371D2CFE5")

    assert KeyWrap.wrap(kek, data) == expected
  end

  test "encrypts literal data with a valid modification code" do
    key = :crypto.strong_rand_bytes(32)
    data = :binary.copy(<<0x42>>, 32)

    assert {:ok, [{18, <<1, ciphertext::binary>>}]} =
             key |> Message.encrypt(data) |> Packet.decode()

    plaintext =
      :crypto.crypto_one_time(
        :aes_256_cfb128,
        key,
        <<0::128>>,
        ciphertext,
        false
      )

    <<prefix::binary-size(18), literal::binary-size(40), 0xD3, 0x14,
      mdc::binary-size(20)>> = plaintext

    assert binary_part(prefix, 14, 2) == binary_part(prefix, 16, 2)

    assert {:ok, [{11, <<?b, 0, 0::32, ^data::binary>>}]} =
             Packet.decode(literal)

    assert mdc == :crypto.hash(:sha, prefix <> literal <> <<0xD3, 0x14>>)
  end

  test "produces v3 ECDH and v1 integrity-protected packets" do
    key = :crypto.strong_rand_bytes(32)

    assert {:ok, encoded} = Lumex.PGP.encrypt_key(key)
    assert {:ok, bytes} = Base.decode64(encoded)

    assert {:ok, [{1, session}, {18, <<1, _::binary>>}]} =
             Packet.decode(bytes)

    assert <<3, _key_id::binary-size(8), 18, 263::16, 0x40,
             _point::binary-size(32), 48, _wrapped::binary-size(48)>> =
             session
  end
end
