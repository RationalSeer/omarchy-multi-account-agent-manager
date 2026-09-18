# Contributing

Thanks for helping. A few things that keep this plugin easy to trust.

## Reporting a problem

Open an issue with the **Bug report** template. The most useful things to
include are the output of `agent-acct status --json` (emails are yours to
redact), `agent-acct setup --status`, `agent-acct tools --all`, and the CLI
versions involved (`claude --version`, `codex --version`, …). Never paste a
credential file.

## Adding or fixing a tool definition

Definitions live in `tools/<id>.json`. A pull request that adds one should:

- say which CLI version you verified it against (the `verified` field),
- keep `identity.jq` free of anything that could print a token,
- ship `enabled: false` if the CLI's auth layout is a guess,
- include a mark in `assets/<id>.svg` (a simple shape reminiscent of the
  product, not its logo) and an `-light` twin if the mark is white.

## Code

- `bin/agent-acct` is bash + jq; run `bash -n bin/agent-acct` and keep
  `set -euo pipefail` happy. No `eval`, no network, no sudo.
- QML follows Omarchy's shared kit (`qs.Ui`, `qs.Commons`); reuse its
  controls rather than restyling.
- Bump `version` in `manifest.json` and add a CHANGELOG entry in the same PR.
- `omarchy plugin validate .` must pass; the GitHub Action runs the same
  checks plus a fresh-home CLI run.

## Testing locally

```bash
git clone <your fork> ~/.config/omarchy/plugins/io.github.rationalseer.multi-account-agent-manager
omarchy plugin enable io.github.rationalseer.multi-account-agent-manager
omarchy restart shell   # QML changes do not always hot-reload
```
