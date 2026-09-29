defmodule StealthKitty.Attachment do
  @moduledoc """
  Formats a local file as prompt text using pyLumo's attachment convention.
  Binary content is base64 encoded before request encryption.
  """

  @max_size 2 * 1024 * 1024

  @type result :: {:ok, binary()} | {:error, term()}

  @doc """
  Reads and formats a file of at most 2 MiB. Text stays readable; binary
  content is base64 encoded. Returns file errors from `File` unchanged.
  """
  @spec format(Path.t()) :: result()
  def format(path) do
    with {:ok, %{size: size}} <- File.stat(path),
         :ok <- check_size(size),
         {:ok, data} <- File.read(path) do
      {:ok, format_data(Path.basename(path), data)}
    end
  end

  defp check_size(size) when size <= @max_size do
    :ok
  end

  defp check_size(_size) do
    {:error, :file_too_large}
  end

  defp format_data(name, data) do
    data
    |> data_kind()
    |> format_content(name, data)
  end

  defp data_kind(data) do
    data
    |> String.valid?()
    |> classify(data)
  end

  defp classify(false, _data) do
    :binary
  end

  defp classify(true, data) do
    data
    |> :binary.match(<<0>>)
    |> classify_match()
  end

  defp classify_match(:nomatch) do
    :text
  end

  defp classify_match(_match) do
    :binary
  end

  defp format_content(:text, name, data) do
    envelope(name, "File contents:", data)
  end

  defp format_content(:binary, name, data) do
    envelope(name, "File contents (base64-encoded):", Base.encode64(data))
  end

  defp envelope(name, heading, content) do
    content = [
      "Filename: ",
      name,
      "\n",
      heading,
      "\n----- BEGIN FILE CONTENTS -----\n",
      content,
      "\n----- END FILE CONTENTS -----"
    ]

    IO.iodata_to_binary(content)
  end
end
