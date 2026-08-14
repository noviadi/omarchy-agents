# Installation & maintenance

## Full install (recommended)

1. **Requirements**: Omarchy 4.x (quattro, ships the agents plugin) and, for
   the Z.ai collector, a credential it can find — one of:
   - `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL` (…z.ai) in
     `~/.claude/settings.json` (i.e. Claude Code set up on the coding plan)
   - `ZAI_API_KEY` in the environment
   - `{"apiKey": "…"}` in `~/.config/zai/key.json`
2. **Clone and install**:
   ```bash
   git clone https://github.com/noviadi/omarchy-agents ~/Developments/code/omarchy-agents
   ~/Developments/code/omarchy-agents/install.sh
   ```
   `install.sh` handles everything: creates the `<username>.agents` plugin
   slot from the first-party plugin (switching the bar to it) if not
   present, installs `bin/*` to `~/.local/bin`, deploys the plugin payload
   (manifest/QML/assets) into the slot, removes obsolete systemd units from
   older setups, and restarts the shell.
3. **Optional** — snappier quota meters and a default tab/pace setup
   (default panel cadence is 15 min):
   ```bash
   omarchy bar set "$(id -un).agents" refreshIntervalSec 300 --json
   ```
   Then edit `~/.config/omarchy/shell.json` for `providerOrder` /
   `showPace` (array values must be edited by hand).

The shell restart triggers a refresh immediately; the Z.ai tab appears as
soon as `~/.local/state/omarchy/agents/usage/zai.json` lands. Claude Code
token history shows up on its tab once Claude Code has run on the machine.

## Marketplace install (`omarchy plugin add`) — panel only

```bash
omarchy plugin add https://github.com/noviadi/omarchy-agents.git --enable --yes
```

This installs **only the panel**. `plugin add` clones the plugin and
enables it — it has no hook to run this repo's installer, and no mechanism
to deploy executables. The panel detects the missing orchestrator and
**falls back to the stock packaged collectors**, so you get a working
claude/codex/fireworks panel — but:

> ⚠️ **The custom providers are NOT active after `plugin add` alone.**
> No Z.ai tab, no API-key Claude transform — until you do the manual step:
>
> ```bash
> git clone https://github.com/noviadi/omarchy-agents ~/Developments/code/omarchy-agents
> ~/Developments/code/omarchy-agents/install.sh    # deploys bin/* to ~/.local/bin
> ```
>
> The panel picks the orchestrator up on the next shell restart.

## Updating an existing install

Re-run `./install.sh` after editing anything in this repo. Plugin-code
changes need the shell restart the script performs; `bin/` scripts are
picked up on the next refresh without one.

## Removal

```bash
omarchy plugin remove "$(id -un).agents"   # delete the plugin slot, bar falls back to stock omarchy.agents
rm -f ~/.local/bin/omarchy-agent-usage-{all,zai} ~/.local/bin/omarchy-agent-claude-apikey-fixup
rm -rf ~/.local/state/omarchy/agents/usage/zai.json   # optional: drop the Z.ai record
```

After removal the stock agents panel takes the bar slot back on the next
shell restart; claude/codex/fireworks records keep refreshing from the
packaged collectors.

## Syncing with upstream Omarchy

The plugin QML is a frozen copy of
`/usr/share/omarchy/shell/plugins/agents/` at Omarchy 4.0.0. When upstream
improves the panel:

```bash
for f in Main.qml Panel.qml Agent.qml; do
  diff "/usr/share/omarchy/shell/plugins/agents/$f" "$f"
done
diff -r /usr/share/omarchy/shell/plugins/agents/assets assets
```

Copy upstream changes over, then re-apply the local patches:

- `Main.qml`: `updateCommand()` calls `omarchy-agent-usage-all`, with the
  startup probe / exit-127 fallback and `applyProviderOrder()`
- `Panel.qml`: `countText` + `windowMs` in `limitWindow()`, the pace tick
  in `LimitRow`/`Meter`
- `assets/zai.svg`, `assets/zai-light.svg`

Then `./install.sh`. Local settings (providerOrder, showPace,
refreshIntervalSec) live in `shell.json` and survive re-installs.
