defmodule StealthKitty.TUI.State do
  @moduledoc """
  Pure state transitions for the terminal chat.
  Network requests are started by the Terra adapter after `start_prompt/2`.
  """

  @type message :: %{role: atom(), content: binary()}

  @type t :: %__MODULE__{
          client: StealthKitty.t(),
          messages: [message()],
          draft: binary(),
          cursor: non_neg_integer(),
          busy: boolean(),
          tick: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer(),
          scroll: non_neg_integer() | nil,
          tools: [binary()],
          attachment: Path.t() | nil,
          input_mode: :prompt | :attachment,
          saved_draft: binary(),
          saved_cursor: non_neg_integer(),
          conversation_id: pos_integer(),
          title: binary(),
          next_id: pos_integer(),
          conversations: %{pos_integer() => map()},
          order: [pos_integer()],
          sidebar_visible: boolean(),
          sidebar_focus: boolean(),
          sidebar_selection: non_neg_integer(),
          help_visible: boolean()
        }

  @session_fields [
    :client,
    :messages,
    :draft,
    :cursor,
    :busy,
    :scroll,
    :tools,
    :attachment,
    :input_mode,
    :saved_draft,
    :saved_cursor,
    :conversation_id,
    :title
  ]

  defstruct client: nil,
            messages: [],
            draft: "",
            cursor: 0,
            busy: false,
            tick: 0,
            width: 80,
            height: 24,
            scroll: nil,
            tools: [],
            attachment: nil,
            input_mode: :prompt,
            saved_draft: "",
            saved_cursor: 0,
            conversation_id: 1,
            title: "New conversation",
            next_id: 2,
            conversations: %{},
            order: [1],
            sidebar_visible: false,
            sidebar_focus: false,
            sidebar_selection: 0,
            help_visible: false

  @doc "Creates state with a client and an empty transcript."
  @spec new(StealthKitty.t()) :: t()
  def new(client) do
    tools = StealthKitty.Tools.enable_web_search([], client.web_search)
    %__MODULE__{client: client, tools: tools}
  end

  @doc "Lists conversations in sidebar order, including the active one."
  @spec sidebar_entries(t()) :: [map()]
  def sidebar_entries(state) do
    Enum.map(state.order, fn id ->
      session = session(state, id)

      %{
        id: id,
        title: session.title,
        busy: session.busy,
        active: id == state.conversation_id
      }
    end)
  end

  @doc "Starts a separate in-memory conversation with the current controls."
  @spec new_conversation(t()) :: t()
  def new_conversation(
        %{
          messages: [],
          busy: false,
          draft: "",
          attachment: nil,
          input_mode: :prompt
        } = state
      ) do
    leave_sidebar(state)
  end

  def new_conversation(state) do
    id = state.next_id
    state = stash(state)
    fresh = blank_session(StealthKitty.clear(state.client), id)

    state
    |> Map.merge(fresh)
    |> Map.put(:next_id, id + 1)
    |> Map.put(:order, [id | state.order])
    |> Map.put(:sidebar_selection, 0)
    |> leave_sidebar()
  end

  @doc "Switches to a saved conversation and restores its composer state."
  @spec switch_conversation(t(), pos_integer()) :: t()
  def switch_conversation(%{conversation_id: id} = state, id) do
    leave_sidebar(state)
  end

  def switch_conversation(state, id) do
    case Map.fetch(state.conversations, id) do
      {:ok, saved} ->
        state = stash(state)
        state = %{state | conversations: Map.delete(state.conversations, id)}

        state
        |> Map.merge(saved)
        |> Map.put(
          :sidebar_selection,
          Enum.find_index(state.order, &(&1 == id))
        )
        |> leave_sidebar()

      :error ->
        state
    end
  end

  @doc "Sets whether the conversation sidebar is visible."
  @spec show_sidebar(t(), boolean()) :: t()
  def show_sidebar(state, visible) do
    %{
      state
      | sidebar_visible: visible,
        sidebar_focus: visible and state.width < 96
    }
  end

  @doc "Toggles the sidebar or narrow-screen conversation list."
  @spec toggle_sidebar(t()) :: t()
  def toggle_sidebar(state) do
    show_sidebar(state, not state.sidebar_visible)
  end

  @doc "Shows or hides the keyboard shortcut guide."
  @spec toggle_help(t()) :: t()
  def toggle_help(state) do
    %{state | help_visible: not state.help_visible}
  end

  @doc "Closes the keyboard shortcut guide."
  @spec close_help(t()) :: t()
  def close_help(state) do
    %{state | help_visible: false}
  end

  @doc "Moves keyboard focus between the composer and the wide sidebar."
  @spec toggle_sidebar_focus(t()) :: t()
  def toggle_sidebar_focus(%{sidebar_visible: true, width: width} = state)
      when width >= 96 do
    %{state | sidebar_focus: not state.sidebar_focus}
  end

  def toggle_sidebar_focus(state) do
    state
  end

  @doc "Moves the highlighted conversation in the sidebar."
  @spec move_sidebar_selection(t(), integer()) :: t()
  def move_sidebar_selection(state, delta) do
    last = max(length(state.order) - 1, 0)
    selection = min(max(state.sidebar_selection + delta, 0), last)
    %{state | sidebar_selection: selection}
  end

  @doc "Opens the highlighted conversation."
  @spec select_sidebar_conversation(t()) :: t()
  def select_sidebar_conversation(state) do
    state.order
    |> Enum.at(state.sidebar_selection)
    |> then(&switch_conversation(state, &1))
  end

  @doc "Closes sidebar focus, or the narrow-screen conversation list."
  @spec leave_sidebar(t()) :: t()
  def leave_sidebar(%{width: width} = state) when width < 96 do
    %{state | sidebar_visible: false, sidebar_focus: false}
  end

  def leave_sidebar(state) do
    %{state | sidebar_focus: false}
  end

  @doc "Toggles the web search tool for future prompts."
  @spec toggle_web(t()) :: t()
  def toggle_web(%{tools: []} = state) do
    client = %{state.client | web_search: true}
    %{state | client: client, tools: ["web_search"]}
  end

  def toggle_web(state) do
    client = %{state.client | web_search: false}
    %{state | client: client, tools: []}
  end

  @doc "Selects the next model for future prompts."
  @spec cycle_model(t()) :: t()
  def cycle_model(state) do
    model = StealthKitty.Models.next(state.client.model)
    %{state | client: %{state.client | model: model}}
  end

  @doc "Switches between fast and thinking answers."
  @spec toggle_mode(t()) :: t()
  def toggle_mode(state) do
    effort = StealthKitty.AnswerMode.toggle(state.client.reasoning_effort)
    %{state | client: %{state.client | reasoning_effort: effort}}
  end

  @doc "Opens the file path input while preserving the prompt draft."
  @spec begin_attachment(t()) :: t()
  def begin_attachment(%{input_mode: :attachment} = state) do
    state
  end

  def begin_attachment(state) do
    %{
      state
      | input_mode: :attachment,
        saved_draft: state.draft,
        saved_cursor: state.cursor,
        draft: state.attachment || "",
        cursor: String.length(state.attachment || "")
    }
  end

  @doc "Stores a file path for the next prompt and restores the draft."
  @spec set_attachment(t(), Path.t()) :: t()
  def set_attachment(state, "") do
    restore_prompt(%{state | attachment: nil})
  end

  def set_attachment(state, path) do
    restore_prompt(%{state | attachment: Path.expand(path)})
  end

  @doc "Closes the file path input without changing the attachment."
  @spec cancel_attachment(t()) :: t()
  def cancel_attachment(state) do
    restore_prompt(state)
  end

  @doc "Updates the terminal dimensions."
  @spec resize(t(), pos_integer(), pos_integer()) :: t()
  def resize(state, width, height) do
    old_width = state.width
    state = %{state | width: width, height: height}

    if old_width >= 96 and width < 96 do
      leave_sidebar(state)
    else
      state
    end
  end

  @doc "Moves the transcript window toward older messages."
  @spec scroll_up(t(), non_neg_integer(), pos_integer()) :: t()
  def scroll_up(state, first_visible_line, amount \\ 3) do
    %{state | scroll: max(first_visible_line - amount, 0)}
  end

  @doc "Moves the transcript window toward newer messages."
  @spec scroll_down(t(), non_neg_integer(), non_neg_integer(), pos_integer()) ::
          t()
  def scroll_down(state, first_visible_line, last_start, amount \\ 3) do
    next = first_visible_line + amount
    %{state | scroll: if(next >= last_start, do: nil, else: next)}
  end

  @doc "Follows the latest response again."
  @spec follow_latest(t()) :: t()
  def follow_latest(state) do
    %{state | scroll: nil}
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

    title =
      if state.messages == [], do: conversation_title(prompt), else: state.title

    %{
      state
      | messages: state.messages ++ [message],
        draft: "",
        cursor: 0,
        busy: true,
        title: title,
        scroll: nil,
        attachment: nil
    }
  end

  @doc "Appends one authenticated response chunk to the visible answer."
  @spec append_chunk(t(), binary()) :: t()
  def append_chunk(state, chunk) do
    %{state | messages: append_to_answer(state.messages, chunk)}
  end

  @doc "Routes a streamed chunk to the conversation that started the request."
  @spec append_chunk(t(), pos_integer(), binary()) :: t()
  def append_chunk(state, id, chunk) do
    update_conversation(state, id, &append_chunk(&1, chunk))
  end

  @doc "Completes an answer and stores its updated client history."
  @spec complete(t(), StealthKitty.response(), StealthKitty.t()) :: t()
  def complete(state, response, client) do
    messages = replace_answer(state.messages, response["message"])
    client = keep_controls(client, state.client)
    %{state | client: client, messages: messages, busy: false}
  end

  @doc "Routes a completed answer to its original conversation."
  @spec complete(t(), pos_integer(), StealthKitty.response(), StealthKitty.t()) ::
          t()
  def complete(state, id, response, client) do
    update_conversation(state, id, &complete(&1, response, client))
  end

  @doc "Adds an error to the transcript and releases the input."
  @spec fail(t(), term()) :: t()
  def fail(state, reason) do
    message = %{role: :error, content: error_message(reason)}
    messages = mark_incomplete(state.messages)
    %{state | messages: messages ++ [message], busy: false}
  end

  @doc "Routes a failed request to its original conversation."
  @spec fail(t(), pos_integer(), term()) :: t()
  def fail(state, id, reason) do
    update_conversation(state, id, &fail(&1, reason))
  end

  defp session(%{conversation_id: id} = state, id) do
    snapshot(state)
  end

  defp session(state, id) do
    Map.fetch!(state.conversations, id)
  end

  defp blank_session(client, id) do
    client
    |> new()
    |> Map.put(:conversation_id, id)
    |> snapshot()
  end

  defp snapshot(state) do
    Map.take(state, @session_fields)
  end

  defp stash(state) do
    %{
      state
      | conversations:
          Map.put(state.conversations, state.conversation_id, snapshot(state))
    }
  end

  defp update_conversation(%{conversation_id: id} = state, id, fun) do
    fun.(state)
  end

  defp update_conversation(state, id, fun) do
    case Map.fetch(state.conversations, id) do
      {:ok, saved} ->
        updated = state |> Map.merge(saved) |> fun.() |> snapshot()
        %{state | conversations: Map.put(state.conversations, id, updated)}

      :error ->
        state
    end
  end

  defp conversation_title(prompt) do
    prompt
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 48)
  end

  defp mark_incomplete(messages) do
    case Enum.reverse(messages) do
      [%{role: :assistant} = answer | rest] ->
        Enum.reverse([Map.put(answer, :incomplete, true) | rest])

      _other ->
        messages
    end
  end

  defp append_to_answer(messages, chunk) do
    messages
    |> Enum.reverse()
    |> append_reversed(chunk)
    |> Enum.reverse()
  end

  defp restore_prompt(state) do
    %{
      state
      | input_mode: :prompt,
        draft: state.saved_draft,
        cursor: state.saved_cursor,
        saved_draft: "",
        saved_cursor: 0
    }
  end

  defp keep_controls(client, controls) do
    %{
      client
      | model: controls.model,
        reasoning_effort: controls.reasoning_effort,
        web_search: controls.web_search
    }
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

  defp error_message(:enoent) do
    "The attached file could not be found."
  end

  defp error_message(:file_too_large) do
    "The attached file exceeds the 2 MiB limit."
  end

  defp error_message(reason) do
    inspect(reason)
  end
end
