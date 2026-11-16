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

## macOS platform-verifier TLS failure (`OSStatus -26276`) — fixed by config

A macOS **native** binary whose HTTPS client verifies certificates through the OS platform
verifier (`Security.framework`) fails in-sandbox with `OSStatus -26276`
(`errSecInternalComponent`, a trust-evaluation failure, not a missing CA). Go surfaces it as
`tls: failed to verify certificate: x509: OSStatus -26276`; Rust surfaces it as
`InvalidCertificate(Other(OtherError("OSStatus -26276: -26276")))`. CA-bundle env knobs
(`SSL_CERT_FILE`, `GODEBUG=x509usefallbackroots=1`) do not help.

**Root cause.** The verifier asks the `trustd` Mach service to evaluate the chain, and the
Seatbelt sandbox denies that Mach lookup.

**Fix — no bypass needed.** Allow the lookup and the hosts in the user `settings.json`:

```json
"sandbox": {
  "network": {
    "allowedDomains": ["<each host the CLI calls>"],
    "allowMachLookup": ["com.apple.trustd.agent", "com.apple.trustd"]
  }
}
```

With that in place the CLI works **inside** the sandbox: do not reach for
`dangerouslyDisableSandbox`, and do not put the CLI in `excludedCommands`. A host the CLI
needs that is missing from `allowedDomains` shows up as a `deny network-outbound <host>:443`
sandbox violation instead, a different error: add the host.

### If `-26276` comes back

1. Check that `sandbox.network.allowMachLookup` still lists both `trustd` services in the
   live settings (a settings sync or rewrite can drop it).
2. Probe in-sandbox with the call prefixed by `env` (so no `excludedCommands` entry can
   match and run it unsandboxed), e.g. `env gh api user`.
3. If it still fails with both entries present, report it rather than bypassing.

Notes:

- **Keychain is NOT blocked.** A CLI reporting "the token in keyring is invalid" under
  this failure is showing a symptom of the TLS block, not an expired credential.
- `excludedCommands` entries use `Bash(...)` rule syntax: a bare `gh` matches only `gh`
  with no arguments (use `gh *`). Redirects to files, `;`/`&&` chains, heredocs and
  commands named through a variable stay sandboxed regardless.
- Do **not** build a token-extraction + `curl` shim to route a blocked CLI around the
  approval gate.

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

## SSH commit-signing failure — a SEPARATE confirmed sandbox restriction

Distinct mechanism from the macOS platform-verifier TLS failure above — keep them separate.

**Signature.** A signed `git commit` fails with:

```
error: Couldn't get agent socket?
fatal: failed to write commit object
```

and `ssh-add -l` inside the sandbox returns `Error connecting to agent: Operation not
permitted`.

**Root cause.** With SSH-format commit signing (`gpg.format=ssh`, `commit.gpgsign=true`)
backed by the macOS keychain ssh-agent, the agent's only socket is the launchd bootstrap
endpoint (`/var/run/com.apple.launchd.*/Listeners`). The Claude Code Bash sandbox refuses
the `connect()` to it. This holds even though that path is in
`sandbox.network.allowUnixSockets`, and a symlink to a non-launchd path is resolved back to
the launchd target and still denied. The key/agent/config are fine — verify by running the
same `ssh-add -l` with the sandbox disabled; it succeeds and lists the signing key. **There
is no `settings.json` fix** for this while the OS keychain agent is the signer.

**What to do.** On `Couldn't get agent socket?` during a commit: recognize it as this known
sandbox limitation (do not re-diagnose as a hook/content/key problem), **ask before
proceeding**, and on approval re-run **only the `git commit`** with
`dangerouslyDisableSandbox: true` — every other command stays sandboxed. Alternatively the
user commits in their own unsandboxed terminal, which always works.

## Rule

> Only use `dangerouslyDisableSandbox: true` reactively, in response to a confirmed
> sandbox error message. There is no proactive exception: the macOS `OSStatus -26276`
> TLS failure is fixed by `sandbox.network.allowMachLookup` (see above), not by bypassing.
>
> The SSH commit-signing failure (`Couldn't get agent socket?`) is a separate confirmed
> sandbox restriction covered in its own section above: recognize it on sight, ask the user
> first, then bypass the sandbox for **only** the `git commit`.
