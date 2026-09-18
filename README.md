<div align="center">

# Multi-Account Agent Manager

**Two subscriptions per AI coding CLI. Switch, sign in, watch limits, rotate — from the Omarchy bar.**

Claude Code · Codex · Cursor · Grok · OpenCode · Gemini — and any CLI you describe in a JSON file.

[![Omarchy plugin](https://img.shields.io/badge/Omarchy-plugin-7aa2f7)](https://plugins.omarchy.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![validate](https://github.com/RationalSeer/omarchy-multi-account-agent-manager/actions/workflows/validate.yml/badge.svg)](https://github.com/RationalSeer/omarchy-multi-account-agent-manager/actions/workflows/validate.yml)

<img src="preview.png" width="560" alt="The panel: one tab per tool, one card per account with limits and actions">

</div>

---

## Why

Rate limits are per account. If you keep a second subscription for the days
the first one runs dry, you end up juggling `CLAUDE_CONFIG_DIR`, `CODEX_HOME`
and friends by hand and never quite knowing which account a terminal will
use. This plugin makes the *account* a first-class thing in the bar: see which
one is live per tool, how much of its window is used, switch with a click, and
optionally let it rotate for you at the limit.

## What you see

| | |
|---|---|
| <img src="docs/bar.png" alt="bar"> | **Bar** — one mark per tool you are signed in to, with the live account's badge (`α`, `Ω`, or whatever you name them). Urgent colour when that account needs a login; accent when a limit is past your threshold. Left-click opens the panel, middle-click cycles Claude, scroll cycles Codex, right-click opens a terminal with the active accounts' environment. |
| <img src="preview.png" alt="panel"> | **Panel** — a tab per tool, and for the selected tool one card per account: masked email, plan, session/weekly meters with reset times. **Login** is always there; **Use**, **Launch** and **Shell** appear on hover. The `● Alpha` pill cycles the active account. Tools without published limits (Grok, Cursor, Gemini) show an activity meter — today against the week's busiest day — estimated from local session files. |
| <img src="docs/settings.png" alt="settings"> | **Settings** (gear or `s`) — warn/rotate thresholds as sliders, notifications, per-tool auto-rotate and in-bar switches, **account names and badges**, add/forget accounts, email display, bar options, the setup checklist, and the registry editor. |
| <img src="docs/stock-agents-tabs.png" alt="stock Agents panel"> | **Omarchy's own Agents panel** grows one tab per account ("Claude α", "Codex Ω") with its full charts — this plugin writes per-account usage records in the format the stock collectors use, so nothing is drawn twice. |

## Quick start

```bash
omarchy plugin add https://github.com/RationalSeer/omarchy-multi-account-agent-manager --enable
```

1. The icon appears in the bar as soon as one supported CLI is signed in. Open the panel.
2. Press the gear → **Run setup** (optional, reversible — see below). This is what makes a switch reach every terminal and keybind launch.
3. Pick a tool's second row (*Omega* by default) and press **Login**; the CLI's own sign-in runs in a terminal.
4. Rename the accounts to whatever fits — Main / Alt, Work / Personal — in Settings → Accounts.
5. Click **Use** on an account, or turn on **auto-rotate** for the tool and forget about it.

Everything the panel does is also `agent-acct …` in a terminal (`agent-acct --help`).

## Keys

| Key | Action | | Key | Action |
|---|---|---|---|---|
| `j` / `k` | select account | | `h` / `l` | previous / next tool |
| `Enter` | use this account for new launches | | `a` | all tools at once / one tab |
| `o` | launch the CLI on it | | `r` | refresh usage |
| `i` | sign in | | `s` | settings |
| `t` | terminal with its environment | | `e` | edit the registry |
| `?` | this legend | | `Esc` | back / close |

## Setup — what it wires, what it touches

The widget works immediately. **Run setup** adds the optional wiring, each step shown with ✓/✗ and each reversible with `agent-acct setup --remove`:

| Step | What it does | Undo |
|---|---|---|
| Registry | `~/.config/agent-accounts/accounts.json`: one *Alpha* account per discovered CLI (your current login) and an empty *Omega* | delete |
| PATH | `~/.local/bin/agent-acct` → the plugin's `bin/agent-acct` | `setup --remove` |
| Bash hook | two lines in `~/.bashrc`; new **and already-open** terminals follow a switch at their next prompt, never overriding a value you exported yourself | `setup --remove` |
| Session env | `~/.config/uwsm/env.d/20-agent-accounts` so keybind / menu launches start on the active accounts; `use` also pushes the env into the running Hyprland session | `setup --remove` |
| Timer | `systemd --user` timer refreshing usage every 15 minutes | `setup --remove` |
| Stock tabs | hides the stock single-account Claude/Codex tabs so accounts are not shown twice | `setup --remove` |

Nothing outside your home directory is touched. **No sudo or pkexec is required.**
After `omarchy plugin update`, the wiring is regenerated automatically on the next panel load — only if you had run setup before.

## How a switch works

Every tool is one of two kinds:

- **env** (Claude, Codex, Grok, Gemini): the CLI reads its config directory
  from an environment variable (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`,
  `GROK_HOME`, `GEMINI_CLI_HOME`). An account is a directory: the first one is
  the CLI's default, the second is `~/.<tool>-<account>` with shared config
  (`settings.json`, skills, …) symlinked from the first. `use` rewrites
  `active.env`; the bash hook and the session env carry it. Explicit values
  always win, and `claude-omega` / `codex-alpha` style aliases give one-off
  overrides.
- **link** (Cursor, OpenCode): the CLI reads one fixed auth file
  (`~/.config/cursor/auth.json`, `~/.local/share/opencode/auth.json`). An
  account is a slot under `~/.config/agent-accounts/slots/`, and the fixed
  path is a symlink that `use` re-points. **Login** makes the account active
  first so the sign-in lands in the right slot. *Switch these with no session
  of that tool open* — a running session that refreshes its token would write
  it into whichever slot is linked at that moment.

Running sessions of any tool keep the account they started with. A switch is
for the next launch.

## Alerts and auto-rotate

- **Warn** (default 85 %): one notification per crossing, per account and
  window; also tints the bar badge.
- **Reset notice** (on by default): when a window you were warned about
  resets, one notification so you remember to switch back.
- **Auto-rotate** (per tool, off by default; needs published limits, so
  Claude and Codex): when the active account passes the rotate threshold
  (default 90 %) and another signed-in account has headroom, the tool switches
  to it and notifies. Env-mode tools only; never while it would need to touch
  a running session.

## Keybindings

Anything the panel does is one IPC call away. In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + A", "Agent accounts", "omarchy-shell io.github.rationalseer.multi-account-agent-manager toggle")
o.bind("SUPER + SHIFT + C", "Next Claude account", "omarchy-shell io.github.rationalseer.multi-account-agent-manager next claude")
o.bind("SUPER + SHIFT + X", "Launch Codex on the active account", "agent-acct launch codex")
```

IPC: `omarchy-shell io.github.rationalseer.multi-account-agent-manager <open|close|toggle|settings|tab <tool>|refresh|next <tool>|status>`

## Adding a tool

Drop `~/.config/agent-accounts/tools/<id>.json` (same shape as the files in
[`tools/`](tools); a file with an existing id overrides it):

```json
{
  "id": "foo", "name": "Foo", "order": 65, "bin": "foo",
  "mode": "env", "envVar": "FOO_HOME", "defaultDir": "~/.foo",
  "credFile": "auth.json",
  "login": ["foo", "login"], "logout": ["foo", "logout"],
  "shared": ["config.toml"],
  "identity": { "jq": "{signedIn: ((.token // \"\") | length > 0), email: (.email // \"\"), plan: \"\", expiresAt: null, expired: false}" },
  "collector": "local",
  "localUsage": { "dirs": ["~/.foo/sessions"] }
}
```

`identity.jq` runs over the credential file with `$now` (ms) bound and must
return `{signedIn, email, plan, expiresAt, expired}`. `collector` is
`stock:<omarchy-agent-usage-…>` for a CLI Omarchy already collects, `local`
to estimate from session files in `localUsage.dirs` (optional `globs`,
`sqlite`), or `null`. `order` sets the tab position. A tool shows up only
when its binary is on `PATH` and the definition is `enabled`. Copilot and Pi
ship disabled with the reason inside their files.

## Settings reference

`omarchy bar set io.github.rationalseer.multi-account-agent-manager <key> <value> --json`

| Key | Default | |
|---|---|---|
| `statusIntervalSec` | 300 | how often the panel re-reads `agent-acct status` |
| `limitWarnPercent` | 85 | bar / meter tint threshold |
| `showGlyphs` | true | show account badges in the bar |
| `compactBar` | false | badges only for tools that need attention |
| `barShowUnsigned` | false | also show tools with no signed-in account |
| `emailDisplay` | masked | `masked` (cyc…@example.com), `hidden`, or `full` |
| `showAllTools` | false | every tool's accounts at once instead of one tab |

Registry-side options (the settings page edits the same values):
`agent-acct config alerts warnAt 0.85 | rotateAt 0.9 | enabled off | resetNotify off`,
`agent-acct config <tool> autoRotate on | barHidden on | hidden on`.

## Remove

```bash
agent-acct setup --remove          # undo the optional wiring (keeps your accounts)
agent-acct setup --remove --purge  # also delete the registry, slots and usage records
omarchy plugin remove io.github.rationalseer.multi-account-agent-manager
```

Your CLIs' own directories (`~/.claude`, `~/.codex`, …) and any second-account
directories are never deleted; remove those yourself if you no longer want
that account's data.

## Privacy and security

- Reads only what it shows: presence/expiry of a credential, the account email
  (masked by default, can be hidden) and plan. Tokens are never printed,
  copied or logged.
- No network requests of its own. Rate limits come from Omarchy's stock
  collectors (Claude, Codex); everything else is estimated from local session
  files and labelled as such.
- No sudo or pkexec is required. The only system integration is a
  `systemd --user` timer you install yourself with **Run setup**.
- Nothing is changed without consent: the widget only reads until you run
  setup, and every setup step is listed and reversible.
- Tool definitions are data, but their `login`/`logout`/`emailCommand` arrays
  are executed with the account's environment. Only add definitions you
  trust; the plugin never evaluates strings from them as shell code, and
  account paths are restricted to a safe character set.
- Registry, `active.env` and slots are created owner-only (`0600` / `0700`).

## Known limits

- The stock Agents widget's own right-click "launch agent" runs from the shell
  process, whose environment is fixed at session start; it follows a switch
  only after `omarchy restart shell`. This plugin's Launch/Shell and keybind
  launches follow immediately.
- Copilot stores its token in the system keyring when one exists, which all
  accounts would share; its definition ships disabled.
- Local usage estimates depend on each CLI's session format and may be empty.
- The stock Agents chip row fits about five account tabs before it crowds.

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Security concerns: [SECURITY.md](SECURITY.md). Changes: [CHANGELOG.md](CHANGELOG.md).

## License

MIT. The Claude and Codex marks are the ones shipped with Omarchy's
first-party Agents plugin (MIT); the other marks are simple original shapes
drawn to be reminiscent of each product, not copies of their logos.
