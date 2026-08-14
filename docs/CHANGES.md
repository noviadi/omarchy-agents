# Differences from the stock agents plugin

Everything this repo changes relative to Omarchy's first-party
`omarchy.agents` plugin (`/usr/share/omarchy/shell/plugins/agents/`) at
Omarchy 4.0.0. Grouped by layer; file references point into this repo.

## New: scripts (`bin/`)

| File | What it does |
|---|---|
| `omarchy-agent-usage-zai` | Z.ai collector. Quotas from `api.z.ai/api/monitor/usage/quota/limit` — TOKENS_LIMIT entries become Session (5-hour) and Weekly (7-day) meters (percent, exact `windowMs`, reset time); the TIME_LIMIT entry becomes the monthly Tool row shown as a count ("7 / 1000"). Plan label from `/api/biz/subscription/list`. Key resolution: `ZAI_API_KEY` / `GLM_API_KEY` → `~/.config/zai/key.json` → `ANTHROPIC_AUTH_TOKEN` in `~/.claude/settings.json` (when Claude Code runs on a Z.ai base URL). Auth failure still prints a record with an actionable status; network failure exits non-zero and keeps the previous record. |
| `omarchy-agent-usage-all` | Orchestrator the panel calls instead of the packaged update. Runs the packaged `omarchy-agent-usage-update` **excluding claude**, runs the packaged claude collector itself and transforms its record in-flight ("Waiting for auth" → empty status + `tierLabel: "API key"`; only when the collector actually reported the auth wait, so OAuth machines are untouched), fans out every executable `~/.local/bin/omarchy-agent-usage-*` concurrently, writes each record atomically. Same flags as the packaged script (`--force`, `--limits-only`, `--except <id>`, agent filters). |
| `omarchy-agent-claude-apikey-fixup` | Standalone, idempotent healing tool for the claude record (same transform). Not called by the orchestrator; kept for manual use. |
| `install.sh` | Deploys `bin/*` to `~/.local/bin` and the plugin payload to the `<username>.agents` slot (auto-creating the slot via `omarchy plugin clone` on a fresh install), removes obsolete systemd units from earlier setups, restarts the shell. |

## New: assets

- `assets/zai.svg` / `assets/zai-light.svg` — Z.ai brand marks (Simple
  Icons slug `zdotai`, CC0). Without them the tab falls back to the bar
  glyph.

## Patched: `Main.qml`

1. **Orchestrator wiring** — `updateCommand()` invokes
   `omarchy-agent-usage-all` instead of `omarchy-agent-usage-update`, so
   every provider refreshes on the panel's native cadence (timer, manual
   `r`, `retryAdvised` 30-second retry).
2. **Startup probe + runtime fallback** — a `command -v` probe runs before
   the first refresh (requests are parked until it settles); if the
   orchestrator is absent, or exits 127 later, the panel falls back to the
   packaged update. A marketplace `plugin add` without the scripts yields
   a working stock-equivalent panel instead of a dead widget.
3. **`providerOrder`** — `applyAgentListing()` reorders ids by the
   optional `providerOrder` setting (listed ids first, in order; unlisted
   alphabetical after). `providers[0]` is both the first switcher chip and
   the tab the panel opens on. Default: unset → stock alphabetical order.

## Patched: `Panel.qml`

1. **Count-based limits** — limit entries may carry `countText`; the row
   shows it (e.g. "7 / 1000") instead of the rounded percentage while the
   meter still fills by percent. Motivation: the Z.ai tool quota is a call
   counter, and "1%" was lossy and read as token usage.
2. **Window span plumbing** — limit entries may carry `windowMs`; stored
   on the window object (falls back to parsing the label). Used by the
   pace tick.
3. **Pace tick (opt-in)** — with `"showPace": true` in the widget's
   shell.json entry, each limit meter draws a tick at the elapsed fraction
   of its window (foreground core over a surface halo, protruding past the
   track so it reads on track, fill, and surface in any theme). Fill short
   of the tick = under pace; fill past it = burning faster than the window
   replenishes. Hidden when span/reset is unknown or the reset already
   passed. Default off.

## Patched: `manifest.json`

- `showPace` default (`false`) + schema entry ("Show pace tick on limit
  meters").

## Unchanged (deliberately)

- Record discovery, rendering, sync/aggregation, IPC (target stays
  `omarchy.agents` even though the plugin slot is `<username>.agents`).
- The claude collector binary itself — the orchestrator runs the stock
  binary and only rewrites three JSON fields of its output.
- Stock settings (`refreshIntervalSec`, `providers`, `sync*`) behave as
  upstream documented them (see `docs/PANEL.md`).

## Re-applying after an upstream sync

The exact hunks to re-apply live in the checklist at the bottom of
[`INSTALL.md`](INSTALL.md).
