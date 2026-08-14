# omarchy-agents

Custom drop-in replacement for Omarchy's first-party agents panel
(`omarchy.agents`), installed as the `noviadi.agents` plugin, plus user-side
usage collectors the panel drives on its own refresh cadence.

## What this adds over the stock plugin

| Piece | File | What it does |
|---|---|---|
| **Z.ai provider** | `bin/omarchy-agent-usage-zai` | Quota meters from `api.z.ai/api/monitor/usage/quota/limit` (5-hour session, 7-day weekly, monthly web searches) + plan name from `/api/biz/subscription/list`. Key: `ZAI_API_KEY`, `~/.config/zai/key.json`, or `ANTHROPIC_AUTH_TOKEN` in `~/.claude/settings.json` (when Claude Code runs on Z.ai). |
| **Z.ai marks** | `plugin/assets/zai.svg`, `zai-light.svg` | White/black brand marks (Simple Icons, slug `zdotai`, CC0). |
| **API-key Claude** | `bin/omarchy-agent-claude-apikey-fixup` | Claude Code here runs on an API key, so OAuth limits never exist; rewrites the claude record to a neutral "API key" hero instead of the red "Waiting for auth" card. |
| **Orchestrator** | `bin/omarchy-agent-usage-all` | Wraps the packaged `omarchy-agent-usage-update`, fans out every `~/.local/bin/omarchy-agent-usage-*` user collector, then applies the fixup. Same flags/contract as the packaged script. |
| **Patched panel** | `plugin/Main.qml` | The one change: the refresh command is `omarchy-agent-usage-all` instead of the packaged update, so every provider refreshes on the panel's native cadence (timer, manual `r`, `retryAdvised` 30s retry). |

Everything else in `plugin/` is a verbatim copy of
`/usr/share/omarchy/shell/plugins/agents/` at Omarchy 4.0.0 — the panel is
provider-agnostic by design: it renders whatever JSON records land in
`~/.local/state/omarchy/agents/usage/`.

## Install

```bash
./install.sh
```

Copies `bin/*` to `~/.local/bin`, `plugin/` to
`~/.config/omarchy/plugins/noviadi.agents/`, removes the obsolete systemd
timer/watcher units, and rescans plugins.

First-time setup (already done on this machine): `omarchy plugin clone
omarchy.agents` creates the `noviadi.agents` slot this installs into.

## Adding another provider

1. Drop an executable `omarchy-agent-usage-<id>` in `bin/` (and
   `~/.local/bin/`) that prints one record following the schema of the zai
   collector: `id`, `name`, `tierLabel`, `limits[]`
   (`{label, percent 0..1, resetsAt ISO}`), `recentDays`, `modelUsage`, …
   Keep `usageStatusText` empty when healthy — any non-empty value renders
   as a red urgent card.
2. Optionally add `plugin/assets/<id>.svg` (+ `<id>-light.svg` for light
   surfaces).
3. Re-run `./install.sh`. The panel discovers the new `usage/<id>.json` on
   its next refresh.

## Sync with upstream

The plugin copy is frozen at Omarchy 4.0.0. When upstream improves the
agents panel:

```bash
# diff your copy against the new packaged version
diff -r /usr/share/omarchy/shell/plugins/agents plugin
```

Re-apply the one-line `updateCommand` patch in `Main.qml` (and the `zai.svg`
assets) after copying changes over.
