# Stealth Kitty

Stealth Kitty is an unofficial Elixir client, CLI, and terminal chat for
[Proton Lumo](https://lumo.proton.me). It uses the encrypted request protocol
described by [pyLumo](https://github.com/Mindgard/pyLumo), with an Elixir API
and a terminal interface built with [Terra](https://github.com/uminocelo/terra).
The transport targets Proton's current chat completions endpoint.

## Quick start

Install Elixir 1.18 or newer with Erlang/OTP 28 or newer. Check your versions
with `elixir --version`, then run:

```sh
git clone https://github.com/cristianodabc/stealth-kitty.git
cd stealth-kitty
mix deps.get
mix stealth_kitty "Explain the BEAM in one paragraph"
```

`mix deps.get` installs dependencies; Mix compiles the project when you run
it. Guest access works without an account, token, or GnuPG. The client omits
the authorization header and encrypts the prompt to Lumo's public key.
[Proton offers limited guest access][guest-access].

For an ongoing conversation in your terminal, run:

```sh
mix stealth_kitty.tui
mix stealth_kitty.tui --web-search
mix stealth_kitty.tui --model lumo-max
mix stealth_kitty.tui --thinking
```

In the terminal chat, use Enter to send, Ctrl+R to cycle models, Ctrl+T to
switch between Fast and Thinking, Ctrl+W to toggle web search, and Ctrl+U to
attach a local file to the next prompt. Type the file path and press Enter;
Esc cancels file selection. Arrow keys scroll the transcript, Ctrl+N starts
a new conversation, and Ctrl+Q quits. It needs an interactive terminal.

## Command line

`mix stealth_kitty` sends one prompt and prints the answer. Each invocation
starts a new conversation. Quote prompts that contain spaces.

```sh
mix stealth_kitty "Hello, Lumo"
mix stealth_kitty --web-search "What is new in Elixir?"
mix stealth_kitty --model lumo-max "Explain this theorem"
mix stealth_kitty --model apertus-15 "Explain this simply"
mix stealth_kitty --thinking "Work through this problem"
mix stealth_kitty --upload notes.pdf "Summarize this file"
mix stealth_kitty --output answer.txt "Write a haiku"
mix stealth_kitty --help
```

Use commas to enable more than one tool, such as
`--tools web_search,weather`. Available tools are `proton_info`,
`web_search`, `weather`, `stock`, and `cryptocurrency`. The default tool list
is empty. `--web-search` adds web search to that list. Use
`--no-web-search` to override an enabled config default. `--upload`
accepts a local file of at most 2 MiB. `--output`
creates or overwrites the named file. Without a prompt argument, the CLI
reads from standard input.

The default model is `lumo-lite`. The web client also offers `apertus-15`
(Apertus 1.5) and `lumo-max` (Lumo 2.0 Max). Availability depends on your
Proton plan and current limits. Fast mode is the default; `--thinking` sends
`reasoning_effort: "high"`. Use `--no-thinking` to override a Thinking default.

## Defaults

Edit `config/config.exs` to choose defaults for all entry points:

```elixir
config :stealth_kitty,
  model: "lumo-lite",
  reasoning_effort: "none",
  web_search: false
```

The CLI's `--model`, `--thinking`, and `--web-search` options override these
defaults. The TUI accepts the same options. In Elixir, pass options to
`StealthKitty.new/1` for a client default or to `StealthKitty.ask/3` for
one request.

## Optional account token

Guest mode needs no configuration. To use an existing Proton bearer token,
set `STEALTH_KITTY_ACCESS_TOKEN` in your environment before starting the CLI,
TUI, or IEx. `config/runtime.exs` loads it for all three. The client does not
account login or refresh tokens, and it does not save the token. An explicit
`:access_token` option to `StealthKitty.new/1` takes priority.

## Elixir API

Start an interactive Elixir session in the project directory with
`iex -S mix`, then call:

```elixir
client = StealthKitty.new()
{:ok, %{"message" => answer}, client} = StealthKitty.ask(client, "Hello, Lumo")
IO.puts(answer)

{:ok, response, client} =
  StealthKitty.ask(client, "What happened today?", web_search: true)

client = StealthKitty.new(model: "apertus-15", reasoning_effort: "high")
```

`ask/3` returns a new client with the successful exchange in memory. Pass that
client to the next call to continue the conversation. `clear/1` starts a new
conversation. `:max_turns` limits retained turns and defaults to 10.

Use `:on_chunk` to receive authenticated message chunks as they arrive:

```elixir
on_chunk = fn "message", chunk -> IO.write(chunk) end
{:ok, _response, client} =
  StealthKitty.ask(client, "Write a short poem", on_chunk: on_chunk)
```

Use `StealthKitty.ask_file/4` to include a local file. Pass
`model: "lumo-max"` when your account has access to the Max tier.

The web composer also shows Proton Drive, sketch, image creation, and
Custom Lumo controls. Those flows need additional account and media APIs;
Stealth Kitty currently handles local text or base64 file attachments and text
responses.

## Encryption and protocol

Stealth Kitty creates a new 256-bit AES key and a request ID for each prompt. It
encrypts the prompt and recent turns with AES-GCM, wraps the AES key to Lumo's
bundled OpenPGP public key, and authenticates each response chunk before
exposing it. The OpenPGP wrapper uses Curve25519 ECDH and an
integrity-protected AES-256 packet. Conversation history stays in process
memory.

The bundled public key matches the one in
[Proton WebClients](https://github.com/ProtonMail/WebClients).
It may need an update when Proton rotates its key. The Lumo endpoint is
unofficial and may change. The client requires a `done` event before accepting
a streamed response, so a truncated response does not enter conversation
history.

## Development

Run `mix quality` for compilation, formatting, dependency and compile-cycle
checks, Credo, and tests. The tests cover encryption, OpenPGP wrapping,
SSE framing, request payloads, attachment formatting, history, and Terra
state.

Copyright 2026 Cristiano Carvalho. Stealth Kitty uses the Apache-2.0
license. See [LICENSE](LICENSE), [NOTICE](NOTICE), and
[the architecture notes](docs/architecture.md).

[guest-access]: https://proton.me/support/lumo-getting-started
