defmodule StealthKitty.Stream do
  @moduledoc """
  Decodes chat completion SSE as bytes arrive. A token reaches callers
  only after AES-GCM authentication succeeds.
  """

  alias StealthKitty.Crypto

  @type callback :: (binary(), binary() -> any())

  @type t :: %__MODULE__{
          key: binary(),
          request_id: binary(),
          callback: callback() | nil,
          buffer: binary(),
          content: map(),
          done: boolean(),
          error: term() | nil
        }

  @type feed_result :: {:ok, t()} | {:error, t()}
  @type result :: {:ok, map()} | {:error, term()}

  defstruct [
    :key,
    :request_id,
    :callback,
    buffer: "",
    content: %{},
    done: false,
    error: nil
  ]

  @doc "Creates a stream decoder for one request."
  @spec new(binary(), binary(), callback() | nil) :: t()
  def new(key, request_id, callback \\ nil) do
    %__MODULE__{key: key, request_id: request_id, callback: callback}
  end

  @doc "Consumes one network chunk and retains an incomplete final line."
  @spec feed(t(), binary()) :: feed_result()
  def feed(state, chunk) do
    {lines, buffer} = split_lines(state.buffer <> chunk)
    reducer = &consume_line/2
    Enum.reduce_while(lines, {:ok, %{state | buffer: buffer}}, reducer)
  end

  @doc """
  Returns accumulated target text after a `done` event. An incomplete
  response or failed integrity check returns an error.
  """
  @spec finish(t()) :: result()
  def finish(state) do
    state.buffer
    |> String.trim_trailing("\r")
    |> parse_line(state)
    |> finish_result()
  end

  defp split_lines(data) do
    parts = String.split(data, "\n")
    lines = parts |> Enum.drop(-1) |> Enum.map(&String.trim_trailing(&1, "\r"))
    {lines, List.last(parts)}
  end

  defp consume_line(line, {:ok, state}) do
    line
    |> parse_line(state)
    |> continuation()
  end

  defp continuation({:ok, state}) do
    {:cont, {:ok, state}}
  end

  defp continuation({:error, state}) do
    {:halt, {:error, state}}
  end

  defp finish_result({:ok, %{error: nil, done: true, content: content}}) do
    {:ok, content}
  end

  defp finish_result({:ok, %{error: nil}}) do
    {:error, :incomplete_response}
  end

  defp finish_result({_status, %{error: reason}}) do
    {:error, reason}
  end

  defp parse_line(_line, %{error: error} = state)
       when not is_nil(error) do
    {:error, state}
  end

  defp parse_line("data:" <> json, state) do
    json
    |> decode_event()
    |> handle_event(state)
  end

  defp parse_line(_line, state) do
    {:ok, state}
  end

  defp decode_event(json) do
    decode_json(String.trim(json))
  end

  defp decode_json("[DONE]") do
    {:ok, :done}
  end

  defp decode_json(json) do
    {:ok, :json.decode(json)}
  catch
    :error, _reason -> {:error, :invalid_response}
  end

  defp handle_event({:error, reason}, state) do
    {:error, %{state | error: reason}}
  end

  defp handle_event({:ok, :done}, state) do
    {:ok, %{state | done: true}}
  end

  defp handle_event({:ok, %{"type" => "done"}}, state) do
    {:ok, %{state | done: true}}
  end

  defp handle_event({:ok, %{"choices" => [choice | _]}}, state) do
    handle_choice(choice, state)
  end

  defp handle_event({:ok, %{"error" => error}}, state) do
    {:error, %{state | error: {:generation, error}}}
  end

  defp handle_event({:ok, %{"type" => type}}, state)
       when type in ["timeout", "error", "rejected", "harmful"] do
    {:error, %{state | error: {:generation, type}}}
  end

  defp handle_event(_event, state) do
    {:ok, state}
  end

  defp handle_choice(%{"finish_reason" => "content_filter"}, state) do
    {:error, %{state | error: {:generation, "harmful"}}}
  end

  defp handle_choice(%{"delta" => delta}, state) do
    decrypt_token(delta, state)
  end

  defp handle_choice(_choice, state) do
    {:ok, state}
  end

  defp decrypt_token(%{"content" => ""}, state) do
    {:ok, state}
  end

  defp decrypt_token(%{"content" => :null}, state) do
    {:ok, state}
  end

  defp decrypt_token(%{"content" => encoded} = delta, state) do
    target = Map.get(delta, "target", "message")

    with true <- delta["encrypted"] == true,
         true <- is_binary(target) and is_binary(encoded),
         {:ok, chunk} <- Crypto.decrypt(encoded, state.key, state.request_id),
         true <- String.valid?(chunk) do
      deliver(state.callback, target, chunk)
      content = Map.update(state.content, target, chunk, &(&1 <> chunk))
      {:ok, %{state | content: content}}
    else
      _other -> {:error, %{state | error: :integrity_error}}
    end
  end

  defp decrypt_token(_delta, state) do
    {:ok, state}
  end

  defp deliver(nil, _target, _chunk) do
    :ok
  end

  defp deliver(_callback, _target, "") do
    :ok
  end

  defp deliver(callback, "message", chunk) do
    callback.("message", chunk)
  end

  defp deliver(_callback, _target, _chunk) do
    :ok
  end
end
