# omarchy-agents

Custom drop-in replacement for Omarchy's first-party agents panel
(`omarchy.agents`), installed as the `<username>.agents` plugin slot, plus
user-side usage collectors the panel drives on its own refresh cadence.

> **Personal config, published as reference.** This encodes this machine's
> setup: Claude Code running on a Z.ai coding plan via `ANTHROPIC_AUTH_TOKEN`
> (no Anthropic OAuth). Most people sign into Claude with OAuth and don't use
> Z.ai — for them the claude transform would do nothing (harmless, it only
> fires on "Waiting for auth") and the zai collector would never produce a
> record, but the frozen plugin copy would still cost them upstream panel
> updates. Fork/steal what's useful. The generally-useful pieces belong
> upstream instead: a `zai` collector + assets in basecamp/omarchy (template:
> Fireworks PR #6488), and API-key awareness in the claude collector.

## What this adds over the stock plugin

| Piece | File | What it does |
|---|---|---|
| **Z.ai provider** | `bin/omarchy-agent-usage-zai` | Quota meters from `api.z.ai/api/monitor/usage/quota/limit` (5-hour session, 7-day weekly, monthly web searches) + plan name from `/api/biz/subscription/list`. Key: `ZAI_API_KEY`, `~/.config/zai/key.json`, or `ANTHROPIC_AUTH_TOKEN` in `~/.claude/settings.json` (when Claude Code runs on Z.ai). |
| **Z.ai marks** | `plugin/assets/zai.svg`, `zai-light.svg` | White/black brand marks (Simple Icons, slug `zdotai`, CC0). |
| **API-key Claude** | `bin/omarchy-agent-usage-all` (claude branch) | Claude Code here runs on an API key, so OAuth limits never exist. The orchestrator excludes claude from the packaged update and writes that record itself, transforming "Waiting for auth" → neutral "API key" hero **in-flight** — the warning never lands on disk, so the panel never flashes it. `bin/omarchy-agent-claude-apikey-fixup` remains as a manual healing tool. |
| **Orchestrator** | `bin/omarchy-agent-usage-all` | Wraps the packaged `omarchy-agent-usage-update` (minus claude), runs the claude collector + transform, and fans out every `~/.local/bin/omarchy-agent-usage-*` user collector — all concurrently. Same flags/contract as the packaged script. |
| **Patched panel** | `plugin/Main.qml` | The one change: the refresh command is `omarchy-agent-usage-all` instead of the packaged update, so every provider refreshes on the panel's native cadence (timer, manual `r`, `retryAdvised` 30s retry). |

Everything else in `plugin/` is a verbatim copy of
`/usr/share/omarchy/shell/plugins/agents/` at Omarchy 4.0.0 — the panel is
provider-agnostic by design: it renders whatever JSON records land in
`~/.local/state/omarchy/agents/usage/`.

## Install

### Fresh Omarchy install

1. **Requirements**: Omarchy 4.x (quattro, ships the agents plugin) and a
   Z.ai credential the collector can find — one of:
   - `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL` (…z.ai) in
     `~/.claude/settings.json` (i.e. Claude Code set up on the coding plan)
   - `ZAI_API_KEY` in the environment
   - `{"apiKey": "…"}` in `~/.config/zai/key.json`
2. **Clone this repo** anywhere:
   ```bash
   git clone <repo-url> ~/Developments/code/omarchy-agents
   cd ~/Developments/code/omarchy-agents
   ```
3. **Run the installer**:
   ```bash
   ./install.sh
   ```
   It handles everything: creates the `<username>.agents` plugin slot from
   the first-party plugin (switching the bar to it) if not present, installs
   `bin/*` to `~/.local/bin`, deploys `plugin/` into the slot, removes any
   obsolete systemd units from older setups, and restarts the shell.
4. **Optional** — snappier quota meters (default panel cadence is 15 min):
   ```bash
   omarchy bar set "$(id -un).agents" refreshIntervalSec 300 --json
   ```

The shell restart triggers a refresh immediately; the Z.ai tab appears as
soon as `~/.local/state/omarchy/agents/usage/zai.json` lands (first run
takes a few seconds). Claude Code token history shows up on its tab the
first time Claude Code has run on the machine.

### Updating an existing install

Re-run `./install.sh` after editing anything in this repo. Plugin-code
changes need the shell restart the script performs; `bin/` scripts are
picked up on the next refresh without one.

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
