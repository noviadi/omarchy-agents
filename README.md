# omarchy-agents

A drop-in replacement for [Omarchy](https://omarchy.org)'s built-in agents
toolbar (usage meters for AI coding subscriptions), extended with custom
providers — plus an orchestrator that drives everything on the panel's own
refresh cadence.

Ships with **Z.ai (GLM Coding Plan)** support and an **API-key-aware Claude
tab**. Designed to be extended: adding a provider is one script, and
[`AGENTS.md`](AGENTS.md) is a complete protocol for an AI agent to research
a provider's usage API and wire it in for you.

## Highlights

| Feature | What you get |
|---|---|
| **Z.ai provider** | Session (5-hour) and weekly quota meters, monthly tool-call count ("7 / 1000"), GLM Coding plan label, brand mark |
| **API-key Claude** | Claude Code on an API key shows a neutral "API key" hero instead of the permanent OAuth "Waiting for auth" warning — transformed in-flight, so the warning never even flashes |
| **Unified cadence** | One orchestrator (`omarchy-agent-usage-all`) runs the packaged collectors *and* user collectors on the panel's native refresh (timer, manual `r`, network retry) — no side timers |
| **Pace tick** | Opt-in (`showPace`): a tick on each meter marks where linear usage *should* be; fill past the tick = burning faster than the window replenishes |
| **Tab order** | `providerOrder` setting; first entry is the tab the panel opens on |
| **Count-based limits** | `countText` on a limit row shows "7 / 1000" instead of a misleading percentage |
| **Graceful degradation** | Without the installer's scripts (e.g. marketplace `plugin add` alone), the panel detects the missing orchestrator and falls back to stock behavior |

> **Personal config, published as reference.** The collectors encode my
> setup (Claude Code on a Z.ai plan, no Anthropic OAuth); yours will differ —
> fork it and ask an agent to add your provider. The architecture
> (orchestrator + record contract) is the reusable part; the collectors are
> examples.

## Quick start

```bash
git clone https://github.com/noviadi/omarchy-agents ~/Developments/code/omarchy-agents
~/Developments/code/omarchy-agents/install.sh
```

Requires Omarchy 4.x and, for the Z.ai collector, a credential it can find
(`ZAI_API_KEY`, `~/.config/zai/key.json`, or Claude Code on a Z.ai base URL).
Full details, the marketplace-only path, updates, and removal:
[`docs/INSTALL.md`](docs/INSTALL.md).

## Configuration

Settings live in the widget's entry in `~/.config/omarchy/shell.json`
(hot-reloads on save). Note `omarchy bar set` mangles array values — edit
the file directly.

```json
{
  "id": "<username>.agents",
  "refreshIntervalSec": 300,
  "providerOrder": ["zai", "claude", "codex", "fireworks"],
  "showPace": true,
  "providers": { "fireworks": { "enabled": false } }
}
```

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `900` | Refresh cadence for every provider |
| `providerOrder` | alphabetical | Tab order; first entry is the default tab |
| `showPace` | `false` | Pace tick on limit meters (rationing cue) |
| `providers.<id>.enabled` | `true` | Hide a provider and skip its collector |
| `syncMode` / `syncDir` / … | off | Cross-machine usage aggregation (stock feature, see [`docs/PANEL.md`](docs/PANEL.md)) |

## Extending

- **Add a provider** — point an AI agent at [`AGENTS.md`](AGENTS.md): the
  full protocol (research the usage API → write the collector → verify).
  By hand: an executable `bin/omarchy-agent-usage-<id>` printing the record
  schema, optionally `assets/<id>.svg`, then `./install.sh`.
- **Keyboard** — the panel has IPC; e.g. bind
  `omarchy-shell omarchy.agents toggle` to a Hyprland key for open/close.

## Documentation

| Doc | Contents |
|---|---|
| [`docs/INSTALL.md`](docs/INSTALL.md) | Install paths (full / marketplace), updating, removal, syncing with upstream Omarchy |
| [`AGENTS.md`](AGENTS.md) | Provider protocol: record schema, collector contract, research playbook |
| [`docs/PANEL.md`](docs/PANEL.md) | The upstream agents panel README (Omarchy 4.0.0), kept for reference |

## License

MIT — see [`LICENSE`](LICENSE). The QML is a modified copy of Omarchy's
agents panel; brand marks are from Simple Icons (CC0). Attribution in the
license file.
