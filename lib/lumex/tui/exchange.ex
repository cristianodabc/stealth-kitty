defmodule Lumex.TUI.Exchange do
  @moduledoc """
  Runs a Lumo request outside Terra's render loop and sends authenticated
  chunks and the final result back as Terra events.
  """

  alias Lumex.TUI.State

  @doc "Starts one request using the client and tools in the current state."
  @spec start(pid(), State.t(), binary()) :: {:ok, pid()}
  def start(runtime, state, prompt) do
    Task.start(fn -> run(runtime, state, prompt) end)
  end

  defp run(runtime, state, prompt) do
    callback = fn _target, chunk -> send_event(runtime, {:chunk, chunk}) end
    options = [tools: state.tools, on_chunk: callback]
    result = Lumex.ask(state.client, prompt, options)
    send_event(runtime, {:response, result})
  rescue
    _error -> send_event(runtime, {:response, {:error, :request_failed}})
  end

  defp send_event(runtime, event) do
    send(runtime, {:terra_events, [event]})
  end
end
