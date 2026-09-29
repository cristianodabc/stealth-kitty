defmodule StealthKitty.TUI.Exchange do
  @moduledoc """
  Runs a Lumo request outside Terra's render loop and sends authenticated
  chunks and the final result back as Terra events.
  """

  alias StealthKitty.TUI.State

  @doc "Starts one request using the client and tools in the current state."
  @spec start(pid(), State.t(), binary()) :: {:ok, pid()}
  def start(runtime, state, prompt) do
    request = Map.take(state, [:conversation_id, :client, :tools, :attachment])
    Task.start(fn -> run(runtime, request, prompt) end)
  end

  defp run(runtime, state, prompt) do
    id = state.conversation_id
    callback = fn _target, chunk -> send_event(runtime, {:chunk, id, chunk}) end

    options = [
      tools: state.tools,
      web_search: "web_search" in state.tools,
      on_chunk: callback
    ]

    result = send_prompt(state, prompt, options)
    send_event(runtime, {:response, id, result})
  rescue
    _error ->
      send_event(
        runtime,
        {:response, state.conversation_id, {:error, :request_failed}}
      )
  end

  defp send_event(runtime, event) do
    send(runtime, {:terra_events, [event]})
  end

  defp send_prompt(%{attachment: nil} = state, prompt, options) do
    StealthKitty.ask(state.client, prompt, options)
  end

  defp send_prompt(state, prompt, options) do
    StealthKitty.ask_file(state.client, prompt, state.attachment, options)
  end
end
