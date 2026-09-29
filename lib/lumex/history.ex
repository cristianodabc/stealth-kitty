defmodule Lumex.History do
  @moduledoc """
  Keeps the recent cleartext turns used to rebuild an encrypted request.
  History stays in memory and is never written by this module.
  """

  @safe_token_limit 115_200

  @doc "Drops the oldest turns until a new prompt fits the context estimate."
  @spec trim([map()], binary()) :: [map()]
  def trim(history, prompt) do
    do_trim(history, prompt)
  end

  @doc "Adds a successful exchange and applies the client's turn limit."
  @spec record(Lumex.t(), [map()], binary(), Lumex.response()) :: Lumex.t()
  def record(client, history, prompt, response) do
    user = %{"role" => "user", "content" => prompt}
    assistant = assistant_turn(response)
    turns = history ++ [user, assistant]
    %{client | history: Enum.take(turns, -client.max_turns)}
  end

  defp do_trim([], _prompt) do
    []
  end

  defp do_trim(history, prompt) do
    history
    |> token_estimate(prompt)
    |> trim_at_limit(history, prompt)
  end

  defp trim_at_limit(estimate, history, _prompt)
       when estimate <= @safe_token_limit do
    history
  end

  defp trim_at_limit(_estimate, [_oldest | rest], prompt) do
    do_trim(rest, prompt)
  end

  defp token_estimate(history, prompt) do
    chars = Enum.reduce(history, String.length(prompt), &add_turn_length/2)
    div(chars, 4)
  end

  defp add_turn_length(turn, total) do
    fields = ["content", "tool_call", "tool_result"]

    Enum.reduce(fields, total, &add_field_length(&1, &2, turn))
  end

  defp add_field_length(field, total, turn) do
    total + length_of(turn[field])
  end

  defp length_of(nil) do
    0
  end

  defp length_of(value) do
    String.length(value)
  end

  defp assistant_turn(response) do
    %{"role" => "assistant", "content" => response["message"]}
    |> maybe_put("tool_call", response["tool_call"])
    |> maybe_put("tool_result", response["tool_result"])
  end

  defp maybe_put(turn, _field, nil) do
    turn
  end

  defp maybe_put(turn, field, value) do
    Map.put(turn, field, value)
  end
end
