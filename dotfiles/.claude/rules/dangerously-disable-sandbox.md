# dangerouslyDisableSandbox Usage

## What It Does

`dangerouslyDisableSandbox: true` bypasses the Claude Code sandbox for a bash command.
The sandbox restricts certain system calls (network access, file paths outside the
project, etc.). Bypassing it **always prompts the user for approval**, regardless of what
is in the allow list.

## When to Use It

Only set `dangerouslyDisableSandbox: true` when a command fails with a **clear sandbox
restriction error**, such as:

- `Operation not permitted`
- `EPERM`
- `sandbox-exec denied`
- Permission denied on a specific system path

## Go binaries on macOS — a deterministic sandbox failure

There is one narrow, well-understood class where proactively disabling the sandbox is
correct: **Go binaries making outbound HTTPS on macOS.**

Go verifies TLS certificates by calling into macOS `Security.framework`, which the
sandbox blocks at the Mach-service level. The signature is always:

```
tls: failed to verify certificate: x509: OSStatus -26276
```

`OSStatus -26276` is `errSecInternalComponent` — a trust-evaluation failure, **not** a
missing CA. It is confirmed unfixable by `SSL_CERT_FILE` (any bundle) or
`GODEBUG=x509usefallbackroots=1`, and is independent of auth. Non-Go HTTPS clients (e.g.
`curl`) are unaffected in the same sandbox, which is what isolates this to Go's
platform-verifier path.

### Diagnostic before treating a CLI as verified-broken

The predictive criterion is "Go binary making outbound HTTPS on macOS". To confirm a
candidate, run its network probe in-sandbox and check three things:

1. The error is exactly `x509: OSStatus -26276`.
2. `SSL_CERT_FILE` and `GODEBUG=x509usefallbackroots=1` both leave it unchanged.
3. `go version -m "$(command -v <cli>)"` shows it is a Go binary.

A non-Go CLI failing on TLS is a *different* bug — do not treat it as this class.

Notes that keep this exception narrow:

- **Keychain is NOT blocked.** Credential lookups succeed in-sandbox. When a Go CLI
  reports an auth problem under the sandbox (e.g. "the token in keyring is invalid"),
  that message is a misleading symptom of the TLS failure. Don't chase it as an
  expired-credential bug.
- **The network is NOT blocked.** In the same sandbox, `curl` and `git ls-remote` reach
  the same hosts. Adding hosts to the sandbox network allowlist does nothing, because host
  access was never the problem.
- Do **not** build a token-extraction + `curl` shim to route a blocked CLI around the
  approval gate. That is a systematic bypass of a deliberate guardrail, not a bug
  workaround.

## When NOT to Use It

Never set this flag speculatively or as a diagnostic tool. Do not use it when:

- A command returns unexpected output (null fields, empty results, wrong data)
- A command succeeds but the result looks wrong
- You want to "rule out" sandbox interference
- You assume the sandbox might be blocking something without evidence

These are application-level issues unrelated to sandbox restrictions.

## Why This Matters

Setting this flag unnecessarily:

1. Forces a manual approval prompt, bypassing the allow list entirely
2. Slows the user down significantly (approval required every time)
3. Introduces unnecessary security surface

## Rule

> Only use `dangerouslyDisableSandbox: true` reactively, in response to a confirmed
> sandbox error message. The one exception is the macOS Go-TLS class above, where the
> failure is already root-caused and deterministic — and only after the three-step
> diagnostic confirms the CLI is a Go binary and neither env knob helps.
