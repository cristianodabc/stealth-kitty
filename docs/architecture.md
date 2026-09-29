# Architecture

## Boundaries

`Lumex` is the public API. `Lumex.History`, `Lumex.Payload`, `Lumex.Crypto`,
`Lumex.Stream`, and `Lumex.TUI.State` hold the reusable transformations.
`Lumex.HTTP` owns Req calls, `Lumex.PGP` owns OpenPGP encryption, and
`Lumex.TUI.Exchange` runs requests outside Terra's render loop.

## Dependency choices

- Req supplies HTTP streaming and disables automatic retries for generation
  requests. A retry could generate a second answer or repeat a tool action.
- Terra supplies the terminal loop, input widget, layout, and headless render
  support. The chat state and view are separate from network work.
- Erlang `:crypto` supplies Curve25519 ECDH, AES key wrapping primitives,
  AES-CFB, and AES-GCM. The code checks each response tag before delivering a
  chunk.

`Lumex.OpenPGP` modules parse the bundled public key, pin its encryption
subkey fingerprint, wrap a random session key using RFC 6637 and RFC 3394,
and encrypt the request key in a v1 integrity-protected data packet. This
packet format is compatible with Lumo's legacy Curve25519 ECDH key. No
private key, request key, or plaintext message is written to disk.

## Scope

The first release supports guest mode and accepts an existing bearer token.
Proton's account login and token refresh require a separate implementation of
its authentication flow. No account credentials or tokens are saved by Lumex.
