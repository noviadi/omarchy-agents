#!/bin/bash

# Install the custom agents panel over the clone in ~/.config/omarchy/plugins
# and the helper scripts into ~/.local/bin. Re-run after any edit; the shell
# hot-reloads plugin files on save, but a rescan is forced at the end anyway.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# omarchy plugin clone names the user copy <username>.<original>
PLUGIN_ID="$(id -un).agents"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
USER_BIN="$HOME/.local/bin"

# --- scripts -----------------------------------------------------------------
mkdir -p "$USER_BIN"
for script in "$REPO_DIR"/bin/*; do
  install -Dm755 "$script" "$USER_BIN/$(basename "$script")"
done

# --- plugin ------------------------------------------------------------------
# The bar slot must point at $PLUGIN_ID. On a fresh install it still says
# omarchy.agents; cloning the first-party plugin creates the user-owned slot
# and switches the bar to it. This repo is then the source of truth for it.
if ! grep -q "\"$PLUGIN_ID\"" "$HOME/.config/omarchy/shell.json" 2>/dev/null; then
  omarchy plugin clone omarchy.agents
fi
# The repo root IS the plugin (manifest at root, so `omarchy plugin add`
# works too); copy only the plugin payload, not the repo tooling.
mkdir -p "$PLUGIN_DEST"
rm -rf "${PLUGIN_DEST:?}"/*
cp -r "$REPO_DIR/manifest.json" "$REPO_DIR"/*.qml "$REPO_DIR/assets" "$PLUGIN_DEST/"

# --- legacy systemd units ----------------------------------------------------
# Refresh now flows through the panel's own timer calling
# omarchy-agent-usage-all, so the side timers and watchers this repo
# originally shipped with are obsolete.
for unit in omarchy-agent-usage-zai.timer omarchy-agent-usage-zai.service \
  omarchy-agent-claude-apikey.path omarchy-agent-claude-apikey.service; do
  systemctl --user disable --now "$unit" 2>/dev/null || true
  systemctl --user reset-failed "$unit" 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/$unit"
done
systemctl --user daemon-reload 2>/dev/null || true

# --- reload ------------------------------------------------------------------
# rescanPlugins discovers new plugins but does not reliably swap the QML of a
# plugin whose files were replaced; a shell restart does.
omarchy restart shell
echo "Installed $PLUGIN_ID + $(ls "$REPO_DIR/bin" | wc -l) scripts. Old systemd units removed."
