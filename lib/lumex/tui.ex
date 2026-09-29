defmodule Lumex.TUI do
  @moduledoc """
  Terra adapter for the encrypted chat. State changes and rendering live in
  separate modules; this module handles input and starts network requests.
  """

  use Terra

  alias Lumex.TUI.{Exchange, State, View}
  alias Terra.Widget

  @doc "Creates an empty chat using the configured client defaults."
  @impl Terra.App
  @spec init(keyword()) :: {State.t(), [Terra.command()]}
  def init(_options) do
    client = Lumex.new()
    {State.new(client), [{:tick, 120, :tick}]}
  end

  @doc "Processes terminal and network events."
  @impl Terra.App
  @spec update(term(), State.t()) :: State.t() | {:quit, State.t()} | tuple()
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

  defp handle_input({:submit, draft}, state) do
    submit(state, String.trim(draft))
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
