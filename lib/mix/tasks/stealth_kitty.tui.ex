defmodule Mix.Tasks.StealthKitty.Tui do
  @moduledoc """
  Opens the interactive Terra chat for Lumo.

  Use `--model lumo-max`, `--thinking`, and `--web-search` to choose the
  initial controls. `--help` shows the available options.
  """

  use Mix.Task

  @shortdoc "Open the Stealth Kitty terminal chat"

  @type result ::
          {:ok, StealthKitty.TUI.State.t()} | {:error, term()} | :ok

  @doc "Starts the application and runs the Terra terminal interface."
  @impl Mix.Task
  @spec run([binary()]) :: result()
  def run(args) do
    args
    |> parse()
    |> start()
  end

  defp parse(args) do
    options = [
      strict: [
        model: :string,
        thinking: :boolean,
        web_search: :boolean,
        help: :boolean
      ],
      aliases: [h: :help]
    ]

    args
    |> OptionParser.parse(options)
    |> classify()
  end

  defp classify({options, [], []}) do
    effort(options)
  end

  defp classify({_options, words, invalid}) do
    Mix.raise("Invalid options: #{inspect(words ++ invalid)}")
  end

  defp start(options) do
    start(Keyword.get(options, :help, false), options)
  end

  defp start(true, _options) do
    Mix.shell().info(
      "mix stealth_kitty.tui [--model MODEL] [--thinking] [--web-search]"
    )
  end

  defp start(false, options) do
    validate(options)
    Mix.Task.run("app.start")

    Terra.run(
      StealthKitty.TUI,
      app:
        Keyword.take(
          options,
          [:model, :reasoning_effort, :web_search]
        ),
      theme: [accent: :bright_cyan, border: :bright_black]
    )
  end

  defp effort(options) do
    options
    |> Keyword.pop(:thinking)
    |> put_effort()
  end

  defp put_effort({nil, options}) do
    options
  end

  defp put_effort({true, options}) do
    Keyword.put(options, :reasoning_effort, "high")
  end

  defp put_effort({false, options}) do
    Keyword.put(options, :reasoning_effort, "none")
  end

  defp validate(options) do
    client =
      options
      |> Keyword.take([:model, :reasoning_effort, :web_search])
      |> StealthKitty.new()

    validate_model(client.model)
    validate_effort(client.reasoning_effort)
  end

  defp validate_model(model) do
    validate_value(StealthKitty.Models.valid?(model), "Invalid model: #{model}")
  end

  defp validate_effort(effort) do
    validate_value(
      StealthKitty.AnswerMode.valid?(effort),
      "Invalid answer mode: #{effort}"
    )
  end

  defp validate_value(true, _message) do
    :ok
  end

  defp validate_value(false, message) do
    Mix.raise(message)
  end
end
