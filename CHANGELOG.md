# Changelog

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
