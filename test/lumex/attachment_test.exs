defmodule Lumex.AttachmentTest do
  use ExUnit.Case, async: true

  alias Lumex.Attachment

  setup do
    path = Path.join(System.tmp_dir!(), "lumex-file-#{System.unique_integer()}")
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  test "keeps UTF-8 text readable", %{path: path} do
    File.write!(path, "Olá")

    assert {:ok, formatted} = Attachment.format(path)
    assert formatted =~ "File contents:\n"
    assert formatted =~ "Olá"
  end

  test "encodes binary content", %{path: path} do
    File.write!(path, <<0, 255, 10>>)

    assert {:ok, formatted} = Attachment.format(path)
    assert formatted =~ "base64-encoded"
    assert formatted =~ Base.encode64(<<0, 255, 10>>)
  end

  test "rejects files above two mebibytes", %{path: path} do
    File.write!(path, :binary.copy(<<0>>, 2 * 1024 * 1024 + 1))
    assert {:error, :file_too_large} = Attachment.format(path)
  end
end
