defmodule Lumex.OpenPGP.PublicKey do
  @moduledoc """
  Reads Lumo's pinned Curve25519 ECDH encryption subkey.

  The fingerprint pins the complete v4 subkey packet, including its curve,
  public point, and KDF parameters.
  """

  alias Lumex.OpenPGP.{Armor, Packet}

  @key_file Path.expand("../../../priv/lumo-public-key.asc", __DIR__)
  @external_resource @key_file
  @fingerprint Base.decode16!("DA656791F790D0A297C79CCEE7DF128A8FC5DE04")
  @curve_oid <<0x2B, 0x06, 0x01, 0x04, 0x01, 0x97, 0x55, 0x01, 0x05, 0x01>>

  @enforce_keys [:point, :fingerprint, :key_id, :oid]
  defstruct [:point, :fingerprint, :key_id, :oid]

  @type t :: %__MODULE__{
          point: binary(),
          fingerprint: binary(),
          key_id: binary(),
          oid: binary()
        }

  @doc "Loads the pinned encryption subkey from the bundled public key."
  @spec load!() :: t()
  def load! do
    with {:ok, bytes} <- Armor.decode(File.read!(runtime_key_file())),
         {:ok, packets} <- Packet.decode(bytes),
         {14, body} <- Enum.find(packets, &match?({14, _}, &1)),
         {:ok, key} <- parse(body) do
      key
    else
      _ -> raise "invalid bundled Lumo public key"
    end
  end

  defp parse(body) do
    with true <- fingerprint(body) == @fingerprint,
         {:ok, point, oid} <- fields(body) do
      {:ok,
       %__MODULE__{
         point: point,
         fingerprint: @fingerprint,
         key_id: binary_part(@fingerprint, 12, 8),
         oid: oid
       }}
    else
      _ -> :error
    end
  end

  defp fields(
         <<4, _created::32, 18, oid_size, oid::binary-size(oid_size), _bits::16,
           0x40, point::binary-size(32), 3, 1, 8, 7>>
       ) do
    validate_curve(point, oid)
  end

  defp fields(_body) do
    :error
  end

  defp validate_curve(point, @curve_oid) do
    {:ok, point, @curve_oid}
  end

  defp validate_curve(_point, _oid) do
    :error
  end

  defp fingerprint(body) do
    :crypto.hash(:sha, <<0x99, byte_size(body)::16, body::binary>>)
  end

  defp runtime_key_file do
    Application.app_dir(:lumex, "priv/lumo-public-key.asc")
  end
end
