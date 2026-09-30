# Configuration

[Back to the README](../README.md) ·
[Read the architecture](architecture.md)

Guest mode works with the defaults below. Settings in `config/config.exs`
apply to the CLI, TUI, and Elixir API. Options passed to a command or API
call override those defaults.

## Defaults

```elixir
config :stealth_kitty,
  model: "lumo-lite",
  reasoning_effort: "none",
  web_search: false
```

| Setting | Default | Values |
| --- | --- | --- |
| `model` | `lumo-lite` | `lumo-lite`, `lumo-max`, `apertus-15` |
| `reasoning_effort` | `none` | `none` (Fast), `high` (Thinking) |
| `web_search` | `false` | `true` or `false` |

Model availability depends on your Proton plan and current limits. A
`StealthKitty.new/1` option overrides the application default for that
client; an `ask/3` option overrides it for one request. The client's
`:max_turns` option defaults to 10 and limits retained turns in memory.

## Guest and account access

No token is needed for guest mode. To use an existing Proton bearer token,
set `STEALTH_KITTY_ACCESS_TOKEN` before starting Mix or IEx. The value is
loaded by `config/runtime.exs` and is never written by Stealth Kitty.

```sh
export STEALTH_KITTY_ACCESS_TOKEN="your-existing-token"
mix stealth_kitty.tui
```

An explicit `:access_token` option to `StealthKitty.new/1` takes priority.
The project does not implement account login or token refresh.

## Command options

| Option | CLI | TUI | Effect |
| --- | :---: | :---: | --- |
| `--model MODEL` | ✓ | ✓ | Select a supported model |
| `--theme THEME` | | ✓ | Start with the `classic`, `ocean`, or `amber` terminal palette |
| `--thinking` | ✓ | ✓ | Use Thinking mode |
| `--no-thinking` | ✓ | ✓ | Use Fast mode |
| `--web-search` | ✓ | ✓ | Enable web search |
| `--no-web-search` | ✓ | ✓ | Disable web search |
| `--tools NAMES` | ✓ | | Enable comma-separated tools |
| `--upload FILE` | ✓ | | Include a local file |
| `--output FILE` | ✓ | | Write the answer to a file |

The CLI accepts `proton_info`, `web_search`, `weather`, `stock`, and
`cryptocurrency` in `--tools`. No tools are enabled by default.
`--web-search` adds `web_search` to the selected list. The TUI exposes a
web-search toggle with Ctrl+W. `--no-web-search` overrides an enabled
default; an explicit `--tools web_search` still selects that tool.
The TUI shows the current theme and cycles palettes with Ctrl+G.

`--upload` accepts a file of at most 2 MiB. UTF-8 text is included as text;
other files are base64 encoded before the prompt is encrypted. In the TUI,
press Ctrl+U to attach a file to the next message. `--output` creates or
overwrites the named file with the answer.

## API options

```elixir
client =
  StealthKitty.new(
    model: "apertus-15",
    reasoning_effort: "high",
    web_search: true,
    max_turns: 10
  )

{:ok, response, client} =
  StealthKitty.ask(client, "What happened today?", timeout: 120_000)
```

`ask/3` also accepts `:model`, `:reasoning_effort`, `:tools`,
`:web_search`, and `:on_chunk`. `ask_file/4` accepts the same request
options after its path argument. Failed requests return `{:error, reason}`
without updating the client history.
