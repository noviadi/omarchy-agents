#!/bin/bash

# Install the custom agents panel over the clone in ~/.config/omarchy/plugins
# and the helper scripts into ~/.local/bin. Re-run after any edit; the shell
# hot-reloads plugin files on save, but a rescan is forced at the end anyway.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_ID="noviadi.agents"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
USER_BIN="$HOME/.local/bin"

# --- scripts -----------------------------------------------------------------
mkdir -p "$USER_BIN"
for script in "$REPO_DIR"/bin/*; do
  install -Dm755 "$script" "$USER_BIN/$(basename "$script")"
done

# --- plugin ------------------------------------------------------------------
# The bar slot in ~/.config/omarchy/shell.json already points at noviadi.agents
# (omarchy plugin clone omarchy.agents). This repo is now the source of truth
# for that slot.
mkdir -p "$PLUGIN_DEST"
rm -rf "${PLUGIN_DEST:?}"/*
cp -r "$REPO_DIR/plugin/." "$PLUGIN_DEST/"

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
