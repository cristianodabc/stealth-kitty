# Stealth Kitty

[![CI][ci-badge]][ci]
[![Release][release-badge]][releases]
[![Elixir][elixir-badge]][requirements]
[![Apache-2.0][license-badge]][license]

An unofficial encrypted Elixir client and terminal chat for
[Proton Lumo][lumo]. Use it as a guest without creating a token, or supply an
existing Proton bearer token. The terminal interface is built with
[Terra][terra].

<img width="800" src="https://github.com/user-attachments/assets/f3262bcf-e41d-494b-be9a-f3bee0d57771" />

**[Quick start](#quick-start) · [Terminal chat](#terminal-chat) ·
[Elixir API](#elixir-api) · [Configuration][configuration] ·
[Architecture][architecture]**

## Quick start

Use Elixir 1.18 or 1.19 with Erlang/OTP 28. CI runs Elixir 1.19 and OTP 28.
Check both versions with `elixir --version`, then run:

```sh
git clone https://github.com/cristianodabc/stealth-kitty.git
cd stealth-kitty
mix deps.get
mix stealth_kitty.tui
```

The TUI needs an interactive terminal. For a single answer instead:

```sh
mix stealth_kitty "Explain the BEAM in one paragraph"
```

Guest access needs no account token or GnuPG. The client omits the
authorization header in guest mode and encrypts requests to Lumo's bundled
public key. [Proton limits guest access][guest-access].

## Terminal chat

Stealth Kitty renders Markdown replies, including headings, emphasis, lists,
quotes, tables, and links with visible destinations. Fenced code has syntax
colors for more than 200 languages, including Python, Ruby, Rust, Go,
JavaScript, TypeScript, Bash, SQL, Elixir, Erlang, and JSON. Unknown languages
remain readable as plain text.

| Key | Action |
| --- | --- |
| Enter | Send a message |
| Ctrl+R | Cycle models |
| Ctrl+T | Toggle Fast and Thinking |
| Ctrl+W | Toggle web search |
| Ctrl+U | Attach a local file to the next message |
| Ctrl+B | Show or hide the conversation list |
| Ctrl+K | Show or hide the keyboard shortcut guide |
| Tab | Focus or leave the sidebar on wide terminals |
| Up / Down | Scroll the chat, or choose a conversation in the list |
| Ctrl+P / Ctrl+F | Move a page up or down in the chat or conversation list |
| Ctrl+E | Return to the latest reply |
| Enter | Send a message, or open the selected conversation |
| Ctrl+N | Start a new conversation |
| Esc | Close the current list or guide; otherwise quit |
| Ctrl+Q | Quit |

After Ctrl+U, enter a file path and press Enter. Esc cancels file selection.
On narrow terminals, Ctrl+B opens the conversation list as a separate view;
Esc returns to the chat. Conversations and drafts stay in memory for the
current run and are not saved to disk.
Choose initial controls from the command line if you prefer:

```sh
mix stealth_kitty.tui --model lumo-max --thinking --web-search
```

## One-off prompts

`mix stealth_kitty` prints one answer and starts a new conversation on each
invocation. Quote prompts with spaces, or pipe a prompt to standard input.

```sh
mix stealth_kitty "Hello, Lumo"
mix stealth_kitty --web-search "What happened today?"
mix stealth_kitty --upload notes.pdf "Summarize this file"
mix stealth_kitty --output answer.txt "Write a haiku"
mix stealth_kitty --help
```

See [configuration][configuration] for models, tools, defaults, file limits,
and the optional account token.

## Elixir API

Start `iex -S mix` in the project directory:

```elixir
client = StealthKitty.new()

{:ok, %{"message" => answer}, client} =
  StealthKitty.ask(client, "Hello, Lumo")

IO.puts(answer)

{:ok, %{"message" => next_answer}, client} =
  StealthKitty.ask(client, "Tell me more")
```

Pass the returned client into the next call to continue the conversation.
`StealthKitty.clear/1` starts a new one. Options to `StealthKitty.new/1`
set client defaults; options to `StealthKitty.ask/3` apply to one request.

```elixir
{:ok, response, client} =
  StealthKitty.ask(client, "What happened today?", web_search: true)

on_chunk = fn "message", chunk -> IO.write(chunk) end

{:ok, response, client} =
  StealthKitty.ask(client, "Write a poem", on_chunk: on_chunk)
```

The callback receives authenticated text as it arrives. The updated client
is returned only after the response completes successfully. Use
`StealthKitty.ask_file/4` to include a local file.

## How it works

Each request gets a fresh AES-256-GCM key and request ID. The client encrypts
the prompt and retained conversation turns, wraps the key to Lumo's pinned
OpenPGP public subkey, and sends the request through Req. It authenticates
each response chunk before showing it, and adds the exchange to in-memory
history only after a complete response. See the [architecture][architecture]
for the data flow and trust boundaries.

This client uses an unofficial endpoint and may need changes if Proton updates
its protocol or public key. It handles text replies, web search, and local
file attachments. Proton Drive, sketch, image generation, Custom Lumo,
account login, and token refresh require additional APIs.
The protocol implementation was informed by [pyLumo][pylumo].

## Development

Run `mix quality` for compilation, formatting, static checks, and tests.
The project uses the [Apache-2.0 license][license].

Copyright 2026 Cristiano Carvalho.

[architecture]: docs/architecture.md
[configuration]: docs/configuration.md
[license]: LICENSE
[lumo]: https://lumo.proton.me
[pylumo]: https://github.com/Mindgard/pyLumo
[terra]: https://github.com/uminocelo/terra
[requirements]: mix.exs
[guest-access]: https://proton.me/support/lumo-getting-started
[ci]: https://github.com/cristianodabc/stealth-kitty/actions/workflows/ci.yml
[releases]: https://github.com/cristianodabc/stealth-kitty/releases
[ci-badge]: https://github.com/cristianodabc/stealth-kitty/actions/workflows/ci.yml/badge.svg
[release-badge]: https://img.shields.io/github/v/release/cristianodabc/stealth-kitty
[elixir-badge]: https://img.shields.io/badge/Elixir-1.18%2B-4B275F
[license-badge]: https://img.shields.io/badge/license-Apache--2.0-blue
