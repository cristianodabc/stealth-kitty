defmodule Lumex.Payload do
  @moduledoc """
  Builds Lumo generation requests. Every build encrypts the retained turns
  again with a fresh AES key and a new request identifier.
  """

  alias Lumex.{Crypto, ID, PGP}

  @type t :: %__MODULE__{
          body: map(),
          key: binary(),
          id: binary()
        }

  @type result :: {:ok, t()} | {:error, term()}

  defstruct [:body, :key, :id]

  @doc """
  Creates a chat completion with encrypted history and a fresh key.
  Options include `:tools` and `:model`.
  """
  @spec build(Lumex.t(), [map()], binary(), keyword()) :: result()
  def build(client, history, prompt, options) do
    key = :crypto.strong_rand_bytes(32)
    id = ID.uuid4()
    turns = turns(client, history, prompt, key, id)

    with {:ok, request_key} <- PGP.encrypt_key(key) do
      body = body(turns, options, request_key, id)
      {:ok, %__MODULE__{body: body, key: key, id: id}}
    end
  end

  defp turns(client, history, prompt, key, id) do
    history
    |> Enum.take(-(client.max_turns - 1))
    |> Enum.flat_map(&history_turns(&1, key, id))
    |> Kernel.++([encrypted_turn("user", prompt, key, id)])
  end

  defp history_turns(turn, key, id) do
    extras = extra_turns(turn, key, id)

    case turn["content"] do
      nil -> extras
      "" -> extras
      content -> extras ++ [encrypted_turn(turn["role"], content, key, id)]
    end
  end

  defp extra_turns(turn, key, id) do
    roles = ["tool_call", "tool_result"]
    Enum.flat_map(roles, &extra_turn(turn, &1, key, id))
  end

  defp extra_turn(turn, role, key, id) do
    case turn[role] do
      nil -> []
      "" -> []
      content -> [encrypted_turn(role, content, key, id)]
    end
  end

  defp encrypted_turn(role, content, key, id) do
    %{
      "role" => role,
      "content" => Crypto.encrypt(content, key, id),
      "encrypted" => true
    }
  end

  defp body(turns, options, request_key, id) do
    body = %{
      "model" => Keyword.get(options, :model, "lumo-lite"),
      "messages" => turns,
      "stream" => true,
      "stream_options" => %{"include_usage" => true},
      "reasoning_effort" => "none",
      "lumo" => %{
        "client_type" => "frontend",
        "target" => "message",
        "request_key" => request_key,
        "request_id" => id
      }
    }

    add_tools(body, Keyword.get(options, :tools, []))
  end

  defp add_tools(body, []) do
    body
  end

  defp add_tools(body, tools) do
    formatted = Enum.map(tools, &%{"name" => &1})
    Map.merge(body, %{"tools" => formatted, "tool_choice" => "auto"})
  end
end
