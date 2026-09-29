defmodule Lumex.CLI do
  @moduledoc """
  Parses one command-line request and passes it to the encrypted client.
  The Mix task handles display and optional file output.
  """

  @type result ::
          {:ok, binary(), Path.t() | nil} | :help | {:error, term()}

  @doc "Runs one command-line prompt using arguments or standard input."
  @spec run([binary()]) :: result()
  def run(args) do
    with {:ok, options, words} <- parse(args),
         {:ok, prompt} <- prompt(words) do
      client = Lumex.new()
      response = request(client, prompt, options)
      output_result(response, options[:output])
    end
  end

  @doc "Returns the usage text shown by the Mix task."
  @spec usage() :: binary()
  def usage do
    "mix lumex [--tools web_search,weather] [--model lumo-lite] " <>
      "[--upload FILE] [--output FILE] PROMPT"
  end

  defp parse(args) do
    options = [
      strict: [
        tools: :string,
        model: :string,
        upload: :string,
        output: :string,
        help: :boolean
      ],
      aliases: [u: :upload, o: :output, h: :help]
    ]

    args
    |> OptionParser.parse(options)
    |> classify_parse()
  end

  defp classify_parse({options, words, invalid}) do
    classify_help(Keyword.get(options, :help, false), options, words, invalid)
  end

  defp classify_help(true, _options, _words, _invalid) do
    :help
  end

  defp classify_help(false, _options, _words, [_ | _] = invalid) do
    {:error, {:invalid_options, invalid}}
  end

  defp classify_help(false, options, words, []) do
    {:ok, options, words}
  end

  defp prompt([_ | _] = words) do
    {:ok, Enum.join(words, " ")}
  end

  defp prompt([]) do
    stdin_prompt(IO.read(:stdio, :eof))
  end

  defp stdin_prompt(:eof) do
    {:error, :missing_prompt}
  end

  defp stdin_prompt(data) do
    {:ok, String.trim(data)}
  end

  defp request(client, prompt, options) do
    request_options = [
      tools: split_option(options[:tools]),
      model: options[:model] || "lumo-lite"
    ]

    send_prompt(client, prompt, options[:upload], request_options)
  end

  defp send_prompt(client, prompt, nil, options) do
    Lumex.ask(client, prompt, options)
  end

  defp send_prompt(client, prompt, path, options) do
    Lumex.ask_file(client, prompt, path, options)
  end

  defp split_option(nil) do
    []
  end

  defp split_option(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp output_result({:ok, response, _client}, path) do
    {:ok, response["message"], path}
  end

  defp output_result({:error, reason}, _path) do
    {:error, reason}
  end
end
