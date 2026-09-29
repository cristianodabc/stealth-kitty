defmodule StealthKitty.StreamTest do
  use ExUnit.Case, async: true

  alias StealthKitty.Stream

  test "assembles split SSE lines and calls back after authentication" do
    key = :crypto.strong_rand_bytes(32)
    id = StealthKitty.ID.uuid4()

    stream =
      Stream.new(key, id, fn target, chunk ->
        send(self(), {:chunk, target, chunk})
      end)

    first = event("message", "Hello", key, id)
    second = event("message", " world", key, id)
    final = event_data(%{"content" => nil, "encrypted" => true})
    wire = first <> second <> final <> "data: [DONE]\n"
    {left, right} = String.split_at(wire, 17)

    assert {:ok, stream} = Stream.feed(stream, left)
    refute_received {:chunk, _, _}

    assert {:ok, stream} = Stream.feed(stream, right)
    assert {:ok, %{"message" => "Hello world"}} = Stream.finish(stream)
    assert_received {:chunk, "message", "Hello"}
    assert_received {:chunk, "message", " world"}
  end

  test "stops at an invalid encrypted token" do
    key = :crypto.strong_rand_bytes(32)
    id = StealthKitty.ID.uuid4()
    stream = Stream.new(key, id)
    bad = event_data(%{"content" => "bad", "encrypted" => true})

    assert {:error, stream} = Stream.feed(stream, bad)
    assert {:error, :integrity_error} = Stream.finish(stream)
  end

  test "reports generation errors" do
    stream = Stream.new(:crypto.strong_rand_bytes(32), StealthKitty.ID.uuid4())

    error = "data: " <> Jason.encode!(%{error: %{code: "rejected"}}) <> "\n"
    assert {:error, stream} = Stream.feed(stream, error)

    assert {:error, {:generation, %{"code" => "rejected"}}} =
             Stream.finish(stream)
  end

  test "rejects a stream without a completion event" do
    key = :crypto.strong_rand_bytes(32)
    id = StealthKitty.ID.uuid4()
    stream = Stream.new(key, id)

    assert {:ok, stream} =
             Stream.feed(stream, event("message", "partial", key, id))

    assert {:error, :incomplete_response} = Stream.finish(stream)
  end

  defp event(target, plaintext, key, id) do
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

    encoded = Base.encode64(nonce <> ciphertext <> tag)

    event_data(%{
      "target" => target,
      "content" => encoded,
      "encrypted" => true
    })
  end

  defp event_data(delta) do
    body = %{choices: [%{delta: delta}]}
    "data: " <> Jason.encode!(body) <> "\n"
  end
end
