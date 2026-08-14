# Adding a provider

This repo extends the Omarchy agents panel with custom providers. A provider
is **one collector script** — the panel is provider-agnostic and renders
whatever JSON records land in `~/.local/state/omarchy/agents/usage/`. This
guide is written for an AI agent asked to add a provider: research the
provider's usage API, write the collector, verify it end to end.

Reference implementation: `bin/omarchy-agent-usage-zai` (remote quota API).
For auth-from-a-sibling-CLI patterns, see how it reads
`~/.claude/settings.json`.

## Architecture (what calls what)

```
panel (plugin/Main.qml, patched)
  └─ omarchy-agent-usage-all            ← orchestrator (bin/)
       ├─ /usr/share/omarchy/bin/omarchy-agent-usage-update   (built-in codex/fireworks/…)
       ├─ built-in claude collector, output transformed in-flight
       └─ ~/.local/bin/omarchy-agent-usage-*                  (user providers — YOURS goes here)
            each prints one JSON record → written to
            ~/.local/state/omarchy/agents/usage/<id>.json
```

The panel discovers agents by listing `*.json` in the usage dir and
hot-reloads file changes. A new record = a new tab, automatically. Unknown
provider ids are enabled by default.

## 1. Research the usage API

Find the API the provider's **own dashboard** uses — that is where live
quota/usage lives. Good sources, in order:

- Search for community usage trackers for the provider (VS Code extensions,
  CLI tools, statusline scripts); their source shows exact endpoints and
  response shapes. The openusage project's `docs/providers/*.md` documents
  many providers' monitor endpoints.
- The provider's official docs (devpack/usage sections), and any official
  Claude Code / Codex plugin that queries quota.
- The provider's dashboard in a browser (devtools network tab) if docs are
  silent — look for `monitor`, `usage`, `quota`, `subscription` paths.

You need: endpoint URLs, auth (API key header? OAuth token? which file
holds it), and the response shape including **reset timestamps** and
**percentage scale** (0–100 vs 0–1 — verify against a known value).

## 2. Write the collector

`bin/omarchy-agent-usage-<id>` (id: lowercase, no dots). Executable, any
language, stdlib only (python3 and bash+jq are available). Contract:

- Prints **one JSON record** to stdout, nothing else (stderr for warnings).
- Accepts `--force` and `--limits-only` flags without failing (ignore them
  if your source has no cache).
- Exits non-zero on failure — the orchestrator then keeps the previous
  record instead of writing garbage.
- Resolve credentials in order: provider env var → provider config file →
  sibling CLI config (e.g. the key a coding tool already stores). Never
  hardcode keys.

### Record schema

Required even if empty (the panel tolerates empties, not absences, for some
views):

| Field | Type | Notes |
|---|---|---|
| `id` | string | matches `<id>` in the filename and script name |
| `name` | string | display name in the hero ("Z.ai") |
| `schemaVersion` | int | `1` |
| `ready` | bool | `true` once any data exists |
| `tierLabel` | string | plan name in the hero ("GLM Coding Pro") |
| `limits` | array | meters, see below |
| `hasLocalStats` | bool | `true` only if token stats come from local files |
| `recentDays` | array | last 7 days, oldest first: `{date, messageCount}` — `messageCount` holds the day's **token total** despite the name |
| `modelUsage` | object | all-time: `{<model>: {inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens}}` |
| `todayTokensByModel` | object | `{<model>: <int>}` |
| `todayPrompts`, `todaySessions`, `todayTotalTokens` | int | |
| `totalPrompts`, `totalSessions`, `activeDays`, `activeDates` | int / array | all-time; `activeDates` as `"YYYY-MM-DD"` strings |
| `updatedAt` | string | ISO 8601 UTC |
| `usageStatusText` | string | **empty when healthy** — any non-empty value renders as a RED urgent card |

Limits entries: `{label, percent, resetsAt}` — `percent` is **0..1** (0.11
= 11%), `resetsAt` is ISO 8601 (convert epoch ms/s yourself). Good labels:
`"Session (5-hour)"`, `"Weekly (7-day)"`. A prepaid/balance provider can
instead set `balance: {remaining, funded, currency, spent, estimated}`.

### The two ways to get data

1. **Remote quota API** (zai pattern): percentages + reset times from the
   provider. Token-by-day/model history unavailable → leave the stat fields
   empty/zero.
2. **Local transcripts** (claude pattern): walk the tool's session files,
   sum `usage` objects per assistant message, dedupe by message id, bucket
   by model and local date. Expensive scans must cache (see the built-in
   claude collector's `cached_scan` for the pattern).

### Auth failure vs network failure

- Auth rejected → still print a valid record with `usageStatusText: "<what
  to do>"` + `authHelpText`, so the user gets an actionable card.
- Network down → exit non-zero, keep the previous record on disk.

## 3. Brand mark (optional)

`plugin/assets/<id>.svg` (light mark for dark surfaces) and optionally
`plugin/assets/<id>-light.svg` (dark mark for light surfaces). Any plain
SVG, any viewBox; check Simple Icons first (CC0). Without a mark the panel
falls back to a text glyph.

## 4. Install and verify

```bash
./install.sh                                   # or just cp bin/<script> ~/.local/bin/
bin/omarchy-agent-usage-<id>                  # must print valid JSON standalone
omarchy-agent-usage-all                        # full refresh; watch stderr
cat ~/.local/state/omarchy/agents/usage/<id>.json | jq .
omarchy-shell omarchy.agents refresh          # force the panel to pick it up
```

Then open the panel (click the bar widget) and confirm: hero shows name +
tierLabel, meters render with sane percentages, no red card when healthy.
`bin/`-only changes need no shell restart; `plugin/` changes do
(`./install.sh` handles it).

## Never

- Never write anything under `/usr/share/omarchy/` — package-owned, wiped
  on update.
- Never put a non-empty `usageStatusText` on a healthy record (red card).
- Never report `percent` on a 0–100 scale — the panel multiplies by 100.
- Don't create per-provider systemd timers — the panel's refresh cadence
  (via the orchestrator) already drives every collector.
