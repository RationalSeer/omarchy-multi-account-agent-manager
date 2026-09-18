# Changelog

## 0.6.0 — 2026-09-18

- Accounts can be named anything: Settings → Accounts renames (label +
  badge), adds and forgets accounts; `agent-acct rename` / `add` / `remove`.
- **Launch** action and `o` key: open the CLI on a given account;
  `agent-acct launch <tool> [<account>]`.
- Reset notifications: when a window you were warned about resets
  (`config alerts resetNotify`).
- Self-heal after updates: setup is stamped with the plugin version and
  re-applied silently when it changes (only for users who ran setup).
- First-run hint when every tool has a single account.
- Fixed: status fields could shift when a definition had an empty field
  (auto-rotate switches were hidden for Claude/Codex); settings pending
  values no longer trigger a binding loop; taller settings view.

## 0.5.0 — 2026-09-18

- Settings apply instantly (optimistic), confirmed by the status re-read;
  `agent-acct status` is ~3× faster (one registry/tool lookup per profile,
  cached CLI email lookups).
- Activity meters for accounts without published limits (Grok, Cursor,
  Gemini): today's prompts/tokens against the week's busiest day.
- Cursor usage is read from its agent transcripts; link-mode usage is
  attributed to the active slot only.
- `showAllTools` setting (`a` key): every tool's accounts at once; tabs then
  scroll to the tool.
- Redrawn provider marks with brand-like shapes and colours (Gemini gradient,
  Codex knot, Cursor cube, Grok X, OpenCode tile).
- IPC `tab <tool>`.
- Tools carry an explicit `order` (Claude, Codex, Cursor, Grok, OpenCode,
  Gemini, then opt-ins); the Codex mark is Omarchy's stock one again.

## 0.4.0 — 2026-09-18

- Panel v3: one tab per tool instead of stacked sections; Use/Shell appear on
  hover or cursor; key legend behind a `?` tooltip; the active pill cycles the
  account. About half the height of v2 with every feature kept.
- Settings page inside the panel (gear / `s` / IPC `settings`): alert and
  rotate thresholds, notifications toggle, per-tool auto-rotate and in-bar
  switches, email display, bar options, setup checklist with Run/Remove,
  registry editor.
- `agent-acct config alerts enabled on|off`, `config <tool> barHidden on|off`;
  status reports `hasLimits` and `barHidden`; auto-rotate is offered only for
  tools with published limits.

## 0.3.0 — 2026-09-18

- Usage records use short names ("Codex Ω") so the stock Agents panel's chip
  row fits four or more accounts.
- Local collector reads sqlite session indexes (Grok), scans only real session
  directories, and writes no record when nothing was used — no phantom tabs.

- Renamed to Multi-Account Agent Manager (`io.github.rationalseer.multi-account-agent-manager`).
- Profile rows show the provider mark with the profile letter pinned to it.
- `emailDisplay` setting: masked (default), hidden, full.
- Edit button fixed (it called a bar helper that does not exist).
- Hardening: no `eval` on tool definitions; profile paths and labels validated;
  Hyprland env values escaped; `setup --purge` only removes this plugin's
  records; timer step re-applies when the plugin moves.

## 0.2.0 — 2026-09-18

- Bar lists only tools with at least one signed-in profile (`barShowUnsigned`
  to show all); the panel still lists every discovered tool.

- Self-contained: the `agent-acct` CLI ships in `bin/`; the widget calls it
  by path. `agent-acct setup` installs the optional wiring (PATH link, bash
  hook, session env, usage timer, stock-tab hiding) idempotently and
  `setup --remove` undoes it; the panel shows a Setup card while anything is
  missing.
- Declarative tools: `tools/<id>.json` definitions with env or link mode,
  identity extraction via jq, user overrides in
  `~/.config/agent-accounts/tools/`. Tools appear only when their binary is on
  PATH. Shipped: claude, codex, grok, cursor, gemini, opencode; copilot and pi
  disabled by default.
- Limit alerts (once per crossing) and opt-in per-tool auto-rotate to the
  profile with headroom; `▲` marks it in the panel.
- Local usage estimates (`bin/collect-local`) for tools without a stock
  collector, written in the stock record format.
- Panel v2: tool chips, section headers with active/auto chips, profile cards
  with meters, key legend. Bar: compact mode.
- State moved to `~/.config/agent-accounts/` (migrated automatically from
  the 0.1 location).

## 0.1.0 — 2026-09-18

- First version: Claude Code + Codex profiles (Alpha/Omega), bar widget,
  panel, per-profile usage records for the stock Agents panel.
