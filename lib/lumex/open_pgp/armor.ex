defmodule Lumex.OpenPGP.Armor do
  @moduledoc "Decodes the bundled ASCII-armored OpenPGP public key."

  @begin_marker "-----BEGIN PGP PUBLIC KEY BLOCK-----"
  @end_marker "-----END PGP PUBLIC KEY BLOCK-----"

  @doc "Returns the binary packet stream inside a public key block."
  @spec decode(binary()) :: {:ok, binary()} | :error
  def decode(armor) do
    with [_, contents] <- String.split(armor, @begin_marker, parts: 2),
         [body, _] <- String.split(contents, @end_marker, parts: 2) do
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take_while(&(!String.starts_with?(&1, "=")))
      |> Enum.join()
      |> Base.decode64()
    else
      _ -> :error
    end
  end
end
