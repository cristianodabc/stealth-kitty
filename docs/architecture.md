# Architecture

## Boundaries

`StealthKitty` is the public API. `StealthKitty.History`,
`StealthKitty.Payload`, `StealthKitty.Crypto`, `StealthKitty.Stream`, and
`StealthKitty.TUI.State` hold reusable transformations. `StealthKitty.HTTP`
owns Req calls, while `StealthKitty.PGP` owns OpenPGP encryption.
`StealthKitty.TUI.Exchange` runs requests outside Terra's render loop.
Model names and answer modes live in `StealthKitty.Models` and
`StealthKitty.AnswerMode`. The terminal stores selected controls in
`StealthKitty.TUI.State` and snapshots them for each request.

## Dependency choices

- Req supplies HTTP streaming and disables automatic retries for generation
  requests. A retry could generate a second answer or repeat a tool action.
- Terra supplies the terminal loop, input widget, layout, and headless render
  support. The chat state and view are separate from network work.
- Erlang `:crypto` supplies Curve25519 ECDH, AES key wrapping primitives,
  AES-CFB, and AES-GCM. The code checks each response tag before delivering a
  chunk.

`StealthKitty.OpenPGP` modules parse the bundled public key, pin its encryption
subkey fingerprint, wrap a random session key using RFC 6637 and RFC 3394,
and encrypt the request key in a v1 integrity-protected data packet. This
packet format is compatible with Lumo's legacy Curve25519 ECDH key. No
private key, request key, or plaintext message is written to disk.

## Scope

The first release supports guest mode and accepts an existing bearer token.
It supports the web client's text models, Fast and Thinking answer modes,
web search, and local file attachments. Proton Drive, sketch, image output,
and Custom Lumo features require other account or media flows.
Proton's account login and token refresh require a separate implementation of
its authentication flow. No account credentials or tokens are saved by
Stealth Kitty.
