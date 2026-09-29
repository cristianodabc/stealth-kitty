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

    state = State.resize(State.new(client), width, height)
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

  def update({:ctrl, :n}, %{busy: true} = state) do
    state
  end

  def update({:ctrl, :n}, state) do
    State.clear(state)
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

  def update({:resize, width, height}, state) do
    State.resize(state, width, height)
  end

  def update(:up, state) do
    State.scroll_up(state)
  end

  def update(:down, state) do
    State.scroll_down(state)
  end

  def update(:tick, state) do
    {State.tick(state), [{:tick, 120, :tick}]}
  end

  def update({:chunk, chunk}, state) do
    State.append_chunk(state, chunk)
  end

  def update({:response, {:ok, response, client}}, state) do
    State.complete(state, response, client)
  end

  def update({:response, {:error, reason}}, state) do
    State.fail(state, reason)
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
