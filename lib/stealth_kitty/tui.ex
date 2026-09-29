defmodule StealthKitty.TUI do
  @moduledoc """
  Terra adapter for the encrypted chat. State changes and rendering live in
  separate modules; this module handles input and starts network requests.
  """

  use Terra

  alias StealthKitty.TUI.{Exchange, State, View}
  alias Terra.Widget

  @type update_result ::
          State.t()
          | {:quit, State.t()}
          | {State.t(), [Terra.command()]}

  @doc "Creates an empty chat sized to the current terminal."
  @impl Terra.App
  @spec init(keyword()) :: {State.t(), [Terra.command()]}
  def init(options) do
    client =
      options
      |> Keyword.take([:model, :reasoning_effort, :web_search])
      |> StealthKitty.new()

    {width, height} =
      Keyword.get_lazy(options, :size, &Terra.Terminal.size/0)

    state =
      client
      |> State.new()
      |> State.resize(width, height)
      |> State.show_sidebar(width >= 96)

    {state, [{:tick, 120, :tick}]}
  end

  @doc "Processes terminal and network events."
  @impl Terra.App
  @spec update(term(), State.t()) :: update_result()
  def update(:interrupt, state) do
    {:quit, state}
  end

  def update({:ctrl, :q}, state) do
    {:quit, state}
  end

  def update({:ctrl, :k}, state) do
    State.toggle_help(state)
  end

  def update(:esc, %{help_visible: true} = state) do
    State.close_help(state)
  end

  def update({:resize, width, height}, state) do
    State.resize(state, width, height)
  end

  def update(:tick, state) do
    {State.tick(state), [{:tick, 120, :tick}]}
  end

  def update({:chunk, id, chunk}, state) do
    State.append_chunk(state, id, chunk)
  end

  def update({:response, id, {:ok, response, client}}, state) do
    State.complete(state, id, response, client)
  end

  def update({:response, id, {:error, reason}}, state) do
    State.fail(state, id, reason)
  end

  def update(_event, %{help_visible: true} = state) do
    state
  end

  def update({:ctrl, :b}, state) do
    State.toggle_sidebar(state)
  end

  def update({:ctrl, :n}, state) do
    State.new_conversation(state)
  end

  def update(:tab, state) do
    State.toggle_sidebar_focus(state)
  end

  def update(:esc, %{sidebar_focus: true} = state) do
    State.leave_sidebar(state)
  end

  def update(:enter, %{sidebar_focus: true} = state) do
    State.select_sidebar_conversation(state)
  end

  def update({:ctrl, :w}, state) do
    State.toggle_web(state)
  end

  def update({:ctrl, :r}, state) do
    State.cycle_model(state)
  end

  def update({:ctrl, :t}, state) do
    State.toggle_mode(state)
  end

  def update({:ctrl, :u}, %{busy: true} = state) do
    state
  end

  def update({:ctrl, :u}, state) do
    State.begin_attachment(state)
  end

  def update({:ctrl, :p}, %{sidebar_focus: true} = state) do
    State.move_sidebar_selection(state, -View.page_size(state))
  end

  def update({:ctrl, :p}, state) do
    {first, last} = View.scroll_position(state)

    if last == 0,
      do: state,
      else: State.scroll_up(state, first, View.page_size(state))
  end

  def update({:ctrl, :f}, %{sidebar_focus: true} = state) do
    State.move_sidebar_selection(state, View.page_size(state))
  end

  def update({:ctrl, :f}, state) do
    {first, last} = View.scroll_position(state)
    State.scroll_down(state, first, last, View.page_size(state))
  end

  def update({:ctrl, :e}, state) do
    State.follow_latest(state)
  end

  def update(:up, %{sidebar_focus: true} = state) do
    State.move_sidebar_selection(state, -1)
  end

  def update(:up, state) do
    {first, last} = View.scroll_position(state)
    if last == 0, do: state, else: State.scroll_up(state, first)
  end

  def update(:down, %{sidebar_focus: true} = state) do
    State.move_sidebar_selection(state, 1)
  end

  def update(:down, state) do
    {first, last} = View.scroll_position(state)
    State.scroll_down(state, first, last)
  end

  def update(:esc, %{busy: true} = state) do
    {:quit, state}
  end

  def update(_event, %{busy: true} = state) do
    state
  end

  def update(event, state) do
    event
    |> Widget.input_event(state.draft, state.cursor)
    |> handle_input(state)
  end

  @doc "Builds the current Terra view."
  @impl Terra.App
  @spec view(State.t()) :: Terra.View.t()
  def view(state) do
    View.render(state)
  end

  defp handle_input({:edit, draft, cursor}, state) do
    State.edit(state, draft, cursor)
  end

  defp handle_input({:submit, path}, %{input_mode: :attachment} = state) do
    State.set_attachment(state, String.trim(path))
  end

  defp handle_input({:submit, draft}, state) do
    submit(state, String.trim(draft))
  end

  defp handle_input(:cancel, %{input_mode: :attachment} = state) do
    State.cancel_attachment(state)
  end

  defp handle_input(:cancel, state) do
    {:quit, state}
  end

  defp handle_input(:ignore, state) do
    state
  end

  defp submit(state, "") do
    state
  end

  defp submit(state, prompt) do
    {:ok, _pid} = Exchange.start(self(), state, prompt)
    State.start_prompt(state, prompt)
  end
end
