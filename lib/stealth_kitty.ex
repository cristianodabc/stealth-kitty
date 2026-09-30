defmodule StealthKitty do
  @moduledoc """
  Encrypted client for Proton Lumo.

  A client keeps conversation turns in memory. Each request gets a new AES key,
  and `ask/3` returns a client with the successful turn added to its history.
  """

  alias StealthKitty.{AnswerMode, Attachment, History, HTTP, Models}
  alias StealthKitty.{Payload, Stream, Tools}

  @type t :: %__MODULE__{
          history: [map()],
          max_turns: pos_integer(),
          access_token: binary() | nil,
          model: binary(),
          reasoning_effort: binary(),
          web_search: boolean()
        }

  @type response :: %{optional(binary()) => binary()}
  @type result :: {:ok, response(), t()} | {:error, term()}

  defstruct history: [],
            max_turns: 10,
            access_token: nil,
            model: "lumo-lite",
            reasoning_effort: "none",
            web_search: false

  @doc """
  Creates an in-memory client. `:max_turns` limits retained user and assistant
  turns. `:access_token` accepts an existing Proton bearer token. `:model`,
  `:reasoning_effort`, and `:web_search` override the application defaults.
  """
  @spec new(keyword()) :: t()
  def new(options \\ []) do
    %__MODULE__{
      max_turns: options |> Keyword.get(:max_turns, 10) |> max_turns!(),
      access_token:
        Keyword.get(
          options,
          :access_token,
          Application.get_env(:stealth_kitty, :access_token)
        ),
      model: Keyword.get(options, :model, config(:model, "lumo-lite")),
      reasoning_effort:
        Keyword.get(
          options,
          :reasoning_effort,
          config(:reasoning_effort, "none")
        ),
      web_search: Keyword.get(options, :web_search, config(:web_search, false))
    }
  end

  @doc "Removes the client's in-memory conversation history."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = client) do
    %{client | history: []}
  end

  @doc """
  Sends an encrypted prompt. Options include `:tools`, `:web_search`,
  `:model`, `:reasoning_effort`, `:timeout`, and `:on_chunk`, a callback for
  authenticated chunks.
  Returns an updated client only after the full response succeeds. Errors
  leave the original client unchanged.
  """
  @spec ask(t(), binary(), keyword()) :: result()
  def ask(%__MODULE__{} = client, prompt, options \\ []) do
    requested_tools = Keyword.get(options, :tools, [])
    web_search? = Keyword.get(options, :web_search, client.web_search)
    tools = Tools.enable_web_search(requested_tools, web_search?)
    model = Keyword.get(options, :model, client.model)
    effort = Keyword.get(options, :reasoning_effort, client.reasoning_effort)

    with :ok <- validate(prompt, tools, model, effort),
         history <- History.trim(client.history, prompt),
         {:ok, payload} <-
           Payload.build(
             client,
             history,
             prompt,
             tools: tools,
             model: model,
             reasoning_effort: effort
           ),
         {:ok, response} <- request(client, payload, options) do
      updated = History.record(client, history, prompt, response)
      {:ok, response, updated}
    end
  end

  @doc """
  Appends a file to a prompt using pyLumo's text or base64 format, then sends
  the encrypted request. Files larger than 2 MiB return `:file_too_large`.
  """
  @spec ask_file(t(), binary(), Path.t(), keyword()) :: result()
  def ask_file(%__MODULE__{} = client, prompt, path, options \\ []) do
    with {:ok, attachment} <- Attachment.format(path) do
      ask(client, prompt <> "\n\n" <> attachment, options)
    end
  end

  defp request(client, payload, options) do
    callback = Keyword.get(options, :on_chunk)
    stream = Stream.new(payload.key, payload.id, callback)
    into = stream_into(stream)

    request_options = [
      access_token: client.access_token,
      timeout: Keyword.get(options, :timeout, 120_000),
      into: into
    ]

    with {:ok, http} <- HTTP.post(payload.body, request_options),
         {:ok, response} <- finish_response(http.body, stream),
         :ok <- require_message(response) do
      {:ok, response}
    end
  end

  defp stream_into(initial) do
    fn {:data, data}, {request, response} ->
      state = stream_state(response.body, initial)

      case Stream.feed(state, data) do
        {:ok, updated} -> {:cont, {request, %{response | body: updated}}}
        {:error, updated} -> {:halt, {request, %{response | body: updated}}}
      end
    end
  end

  defp stream_state(%Stream{} = state, _initial) do
    state
  end

  defp stream_state(_body, initial) do
    initial
  end

  defp finish_response(body, initial) do
    body
    |> stream_state(initial)
    |> Stream.finish()
  end

  defp require_message(%{"message" => message}) when is_binary(message) do
    :ok
  end

  defp require_message(_response) do
    {:error, :missing_message}
  end

  defp validate(prompt, tools, model, effort) do
    with :ok <- validate_prompt(prompt),
         :ok <- validate_tools(tools),
         :ok <- validate_model(model) do
      validate_effort(effort)
    end
  end

  defp validate_prompt(prompt) when not is_binary(prompt) do
    {:error, :invalid_prompt}
  end

  defp validate_prompt(prompt) do
    validate_nonempty(String.trim(prompt))
  end

  defp validate_nonempty("") do
    {:error, :empty_prompt}
  end

  defp validate_nonempty(_prompt) do
    :ok
  end

  defp validate_tools(tools) do
    validate_allowed(valid_tools?(tools), :invalid_tools)
  end

  defp validate_model(model) do
    validate_allowed(Models.valid?(model), :invalid_model)
  end

  defp validate_effort(effort) do
    validate_allowed(AnswerMode.valid?(effort), :invalid_reasoning_effort)
  end

  defp validate_allowed(true, _reason) do
    :ok
  end

  defp validate_allowed(false, reason) do
    {:error, reason}
  end

  defp valid_tools?(tools) when is_list(tools) do
    Enum.all?(tools, &Tools.allowed?/1)
  end

  defp valid_tools?(_tools) do
    false
  end

  defp max_turns!(value) when is_integer(value) and value > 0 do
    value
  end

  defp max_turns!(_value) do
    raise ArgumentError, ":max_turns must be a positive integer"
  end

  defp config(key, default) do
    Application.get_env(:stealth_kitty, key, default)
  end
end
