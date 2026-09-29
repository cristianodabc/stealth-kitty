defmodule Lumex.ID do
  @moduledoc "Generates random version 4 request identifiers."

  import Bitwise

  @doc "Returns a lowercase UUID string with version and variant bits set."
  @spec uuid4() :: binary()
  def uuid4 do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    version = (c &&& 0x0FFF) ||| 0x4000
    variant = (d &&& 0x3FFF) ||| 0x8000

    [a, b, version, variant, e]
    |> Enum.zip([8, 4, 4, 4, 12])
    |> Enum.map_join("-", &format_part/1)
  end

  defp format_part({part, width}) do
    part
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(width, "0")
  end
end
