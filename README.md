# Lumex

Lumex is an unofficial Elixir client, CLI, and terminal chat for
[Proton Lumo](https://lumo.proton.me). It uses the encrypted request protocol
described by [pyLumo](https://github.com/Mindgard/pyLumo), with an Elixir API
and a terminal interface built with [Terra](https://github.com/uminocelo/terra).
The transport targets Proton's current chat completions endpoint.

## Quick start

Install Elixir 1.18 or newer with Erlang/OTP 28 or newer. Check your versions
with `elixir --version`. From the directory containing `mix.exs`, run:

```sh
mix deps.get
mix lumex "Explain the BEAM in one paragraph"
```

The first command installs dependencies; Mix compiles the project when you
run it. Guest access works without an account, token, or GnuPG.

For an ongoing conversation in your terminal, run:

```sh
mix lumex.tui
```

The terminal chat uses Enter to send, arrow keys to scroll, Ctrl+W to toggle
web search, Ctrl+N to start a new conversation, and Ctrl+Q to quit. It needs
an interactive terminal.

## Command line

`mix lumex` sends one prompt and prints the answer. Each invocation starts a
new conversation. Put the prompt in quotes when it contains spaces.

```sh
mix lumex "Hello, Lumo"
mix lumex --tools web_search "What is new in Elixir?"
mix lumex --model lumo-max "Explain this theorem"
mix lumex --upload notes.pdf "Summarize this file"
mix lumex --output answer.txt "Write a haiku"
mix lumex --help
```

Use commas to enable more than one tool, such as
`--tools web_search,weather`. Available tools are `proton_info`,
`web_search`, `weather`, `stock`, and `cryptocurrency`. The default tool list
is empty. `--upload` accepts a local file of at most 2 MiB. `--output`
creates or overwrites the named file. Without a prompt argument, the CLI
reads from standard input.

The default model is `lumo-lite`. `lumo-max` requires an account with access
to the Max tier.

## Optional account token

Guest mode needs no configuration. To use an existing Proton bearer token,
set `LUMEX_ACCESS_TOKEN` in your environment before starting the CLI, TUI, or
IEx. `config/runtime.exs` loads it for all three. Lumex does not perform
account login or refresh tokens, and it does not save the token. An explicit
`:access_token` option to `Lumex.new/1` takes priority.

## Elixir API

Start an interactive Elixir session in the project directory with
`iex -S mix`, then call:

```elixir
client = Lumex.new()
{:ok, %{"message" => answer}, client} = Lumex.ask(client, "Hello, Lumo")
IO.puts(answer)

{:ok, response, client} =
  Lumex.ask(client, "What happened today?", tools: ["web_search"])
```

`ask/3` returns a new client with the successful exchange in memory. Pass that
client to the next call to continue the conversation. `clear/1` starts a new
conversation. `:max_turns` limits retained turns and defaults to 10.

Use `:on_chunk` to receive authenticated message chunks as they arrive:

```elixir
on_chunk = fn "message", chunk -> IO.write(chunk) end
{:ok, _response, client} =
  Lumex.ask(client, "Write a short poem", on_chunk: on_chunk)
```

Use `Lumex.ask_file/4` to include a local file. Pass `model: "lumo-max"` when
your account has access to the Max tier.

## Encryption and protocol

Lumex creates a new 256-bit AES key and a request ID for each prompt. It
encrypts the prompt and recent turns with AES-GCM, wraps the AES key to Lumo's
bundled OpenPGP public key, and authenticates each response chunk before
exposing it. The OpenPGP wrapper uses Curve25519 ECDH and an
integrity-protected AES-256 packet. Conversation history stays in process
memory.

The bundled public key matches the one in
[Proton WebClients](https://github.com/ProtonMail/WebClients).
It may need an update when Proton rotates its key. The Lumo endpoint is
unofficial and may change. Lumex requires a `done` event before accepting a
streamed response, so a truncated response does not enter conversation
history.

## Development

Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, and
`mix test`. The tests cover encryption, OpenPGP wrapping, SSE framing,
request payloads, attachment formatting, history, and Terra state.

Copyright 2026 Cristiano Carvalho. Lumex is licensed under Apache-2.0. See
[LICENSE](LICENSE), [NOTICE](NOTICE), and
[the architecture notes](docs/architecture.md).
