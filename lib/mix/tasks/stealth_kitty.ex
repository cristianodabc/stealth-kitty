defmodule Mix.Tasks.StealthKitty do
  @moduledoc """
  Runs one encrypted Lumo prompt from the command line.
  Use `mix help stealth_kitty` for Mix task help and `--help` for arguments.
  """

  use Mix.Task

  @shortdoc "Send an encrypted prompt to Lumo"

  @doc "Starts the app, runs the prompt, and writes its answer."
  @impl Mix.Task
  @spec run([binary()]) :: :ok | no_return()
  def run(args) do
    Mix.Task.run("app.start")
    args |> StealthKitty.CLI.run() |> present()
  end

  defp present(:help) do
    Mix.shell().info(StealthKitty.CLI.usage())
  end

  defp present({:ok, message, nil}) do
    Mix.shell().info(message)
  end

  defp present({:ok, message, path}) do
    File.write!(path, message)
  end

  defp present({:error, reason}) do
    Mix.raise("Lumo request failed: #{inspect(reason)}")
  end
end
