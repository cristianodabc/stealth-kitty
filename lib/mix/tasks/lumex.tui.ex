defmodule Mix.Tasks.Lumex.Tui do
  @moduledoc "Opens the interactive Terra chat for Lumo."

  use Mix.Task

  @shortdoc "Open the Lumex terminal chat"

  @doc "Starts the application and runs the Terra terminal interface."
  @impl Mix.Task
  @spec run([binary()]) :: {:ok, Lumex.TUI.State.t()} | {:error, term()}
  def run(_args) do
    Mix.Task.run("app.start")
    Terra.run(Lumex.TUI)
  end
end
