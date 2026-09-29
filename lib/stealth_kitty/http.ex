defmodule StealthKitty.HTTP do
  @moduledoc """
  Req transport for encrypted Lumo requests. Callers supply a response consumer
  and work with decrypted messages through `StealthKitty`.
  """

  @url "https://lumo.proton.me/api/ai/v1/chat/completions"

  @type result :: {:ok, Req.Response.t()} | {:error, term()}

  @doc """
  Posts an encrypted payload. `:into` is Req's streaming callback and is
  required. `:access_token` adds an existing bearer token; `:timeout` sets
  the receive timeout in milliseconds. Automatic retries are disabled.
  """
  @spec post(map(), keyword()) :: result()
  def post(payload, options) do
    case Req.post(@url, request_options(payload, options)) do
      {:ok, %Req.Response{status: 200} = response} -> {:ok, response}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, {:transport, reason}}
    end
  end

  defp request_options(payload, options) do
    [
      headers: headers(options[:access_token]),
      json: payload,
      into: Keyword.fetch!(options, :into),
      receive_timeout: Keyword.get(options, :timeout, 120_000),
      connect_options: [timeout: 15_000],
      decode_body: false,
      retry: false
    ]
  end

  defp headers(access_token) do
    base = [
      {"accept", "application/vnd.protonmail.v1+json"},
      {"origin", "https://lumo.proton.me"},
      {"x-pm-appversion", "Other"},
      {"x-pm-locale", "en_US"}
    ]

    authorization(access_token) ++ base
  end

  defp authorization(nil) do
    []
  end

  defp authorization(token) do
    [{"authorization", "Bearer " <> token}]
  end
end
