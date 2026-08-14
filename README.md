# omarchy-agents

Custom drop-in replacement for Omarchy's first-party agents panel
(`omarchy.agents`), installed as the `<username>.agents` plugin slot, plus
user-side usage collectors the panel drives on its own refresh cadence.

> **A personal plugin, but an extensible one.** It ships my providers —
> Z.ai quotas and an API-key Claude Code (no Anthropic OAuth) — and yours
> will differ. The design point is that *providers don't require forking
> anything*: the panel renders whatever JSON records land in the usage
> directory, and [`AGENTS.md`](AGENTS.md) is a complete protocol for an AI
> agent to research your provider's usage API and add its collector
> end to end. Fork this, run `./install.sh`, then just ask an agent to
> "add a provider for \<your service\>" in the repo. The architecture
> (orchestrator + record contract) is the reusable part; the collectors are
> examples.

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

Point an AI agent at [`AGENTS.md`](AGENTS.md) — it contains the full
protocol: research the provider's usage API, write the collector, verify it
end to end. By hand: an executable `omarchy-agent-usage-<id>` in `bin/`
that prints one record (schema in `AGENTS.md`), optionally
`plugin/assets/<id>.svg`, then `./install.sh`. The panel discovers the new
`usage/<id>.json` on its next refresh.

## Sync with upstream

The plugin copy is frozen at Omarchy 4.0.0. When upstream improves the
agents panel:

```bash
# diff your copy against the new packaged version
diff -r /usr/share/omarchy/shell/plugins/agents plugin
```

Re-apply the one-line `updateCommand` patch in `Main.qml` (and the `zai.svg`
assets) after copying changes over.
