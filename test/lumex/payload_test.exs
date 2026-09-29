defmodule Lumex.PayloadTest do
  use ExUnit.Case, async: true

  alias Lumex.Payload

  test "encrypts every turn under one fresh request key" do
    client = Lumex.new(max_turns: 4)

    history = [
      %{"role" => "user", "content" => "Earlier"},
      %{"role" => "assistant", "content" => "Answer"}
    ]

    assert {:ok, payload} =
             Payload.build(
               client,
               history,
               "Next",
               tools: ["web_search"]
             )

    body = payload.body
    assert body["lumo"]["request_id"] == payload.id
    assert body["lumo"]["client_type"] == "frontend"
    assert body["tools"] == [%{"name" => "web_search"}]
    assert body["model"] == "lumo-lite"
    assert body["stream"] == true
    assert length(body["messages"]) == 3
    assert Enum.all?(body["messages"], &(&1["encrypted"] == true))

    assert ["Earlier", "Answer", "Next"] ==
             Enum.map(body["messages"], &decrypt_turn(&1, payload))
  end

  defp decrypt_turn(turn, payload) do
    {:ok, blob} = Base.decode64(turn["content"])
    <<nonce::binary-size(12), rest::binary>> = blob
    ciphertext_size = byte_size(rest) - 16
    <<ciphertext::binary-size(ciphertext_size), tag::binary-size(16)>> = rest
    context = "lumo.request.#{payload.id}.turn"

    :crypto.crypto_one_time_aead(
      :aes_256_gcm,
      payload.key,
      nonce,
      ciphertext,
      context,
      tag,
      false
    )
  end
end
