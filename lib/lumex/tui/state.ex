defmodule Lumex.TUI.State do
  @moduledoc """
  Pure state transitions for the terminal chat.
  Network requests are started by the Terra adapter after `start_prompt/2`.
  """

  @type message :: %{role: atom(), content: binary()}

  @type t :: %__MODULE__{
          client: Lumex.t(),
          messages: [message()],
          draft: binary(),
          cursor: non_neg_integer(),
          busy: boolean(),
          tick: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer(),
          scroll: non_neg_integer(),
          tools: [binary()]
        }

  defstruct client: nil,
            messages: [],
            draft: "",
            cursor: 0,
            busy: false,
            tick: 0,
            width: 80,
            height: 24,
            scroll: 0,
            tools: []

  @doc "Creates state with a client and an empty transcript."
  @spec new(Lumex.t()) :: t()
  def new(client) do
    %__MODULE__{client: client}
  end

  @doc "Clears the transcript and client history."
  @spec clear(t()) :: t()
  def clear(state) do
    %{state | client: Lumex.clear(state.client), messages: [], scroll: 0}
  end

  @doc "Toggles the web search tool for future prompts."
  @spec toggle_web(t()) :: t()
  def toggle_web(%{tools: []} = state) do
    %{state | tools: ["web_search"]}
  end

  def toggle_web(state) do
    %{state | tools: []}
  end

  @doc "Updates the terminal dimensions."
  @spec resize(t(), pos_integer(), pos_integer()) :: t()
  def resize(state, width, height) do
    %{state | width: width, height: height}
  end

  @doc "Moves the transcript window toward older messages."
  @spec scroll_up(t()) :: t()
  def scroll_up(state) do
    %{state | scroll: state.scroll + 3}
  end

  @doc "Moves the transcript window toward newer messages."
  @spec scroll_down(t()) :: t()
  def scroll_down(state) do
    %{state | scroll: max(state.scroll - 3, 0)}
  end

  @doc "Advances the activity indicator."
  @spec tick(t()) :: t()
  def tick(state) do
    %{state | tick: state.tick + 1}
  end

  @doc "Replaces the current text input and cursor."
  @spec edit(t(), binary(), non_neg_integer()) :: t()
  def edit(state, draft, cursor) do
    %{state | draft: draft, cursor: cursor}
  end

  @doc "Adds a submitted prompt and marks the request as active."
  @spec start_prompt(t(), binary()) :: t()
  def start_prompt(state, prompt) do
    message = %{role: :user, content: prompt}

    %{
      state
      | messages: state.messages ++ [message],
        draft: "",
        cursor: 0,
        busy: true,
        scroll: 0
    }
  end

  @doc "Appends one authenticated response chunk to the visible answer."
  @spec append_chunk(t(), binary()) :: t()
  def append_chunk(state, chunk) do
    %{state | messages: append_to_answer(state.messages, chunk)}
  end

  @doc "Completes an answer and stores its updated client history."
  @spec complete(t(), Lumex.response(), Lumex.t()) :: t()
  def complete(state, response, client) do
    messages = replace_answer(state.messages, response["message"])
    %{state | client: client, messages: messages, busy: false}
  end

  @doc "Adds an error to the transcript and releases the input."
  @spec fail(t(), term()) :: t()
  def fail(state, reason) do
    message = %{role: :error, content: error_message(reason)}
    %{state | messages: state.messages ++ [message], busy: false}
  end

  defp append_to_answer(messages, chunk) do
    messages
    |> Enum.reverse()
    |> append_reversed(chunk)
    |> Enum.reverse()
  end

  defp replace_answer(messages, content) do
    messages
    |> Enum.reverse()
    |> replace_reversed(content)
    |> Enum.reverse()
  end

  defp append_reversed([%{role: :assistant} = answer | rest], chunk) do
    [%{answer | content: answer.content <> chunk} | rest]
  end

  defp append_reversed(messages, chunk) do
    [%{role: :assistant, content: chunk} | messages]
  end

  defp replace_reversed([%{role: :assistant} = answer | rest], content) do
    [%{answer | content: content} | rest]
  end

  defp replace_reversed(messages, content) do
    [%{role: :assistant, content: content} | messages]
  end

  defp error_message({:http_status, status}) do
    "Lumo returned HTTP #{status}."
  end

  defp error_message({:generation, type}) do
    "Lumo reported #{type}."
  end

  defp error_message(:integrity_error) do
    "Response integrity check failed."
  end

  defp error_message(:incomplete_response) do
    "Lumo ended the response before it completed."
  end

  defp error_message(reason) do
    inspect(reason)
  end
end
