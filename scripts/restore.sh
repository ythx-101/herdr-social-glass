#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
BASELINE="$STATE_DIR/baseline-config.toml"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"

if [[ ! -f "$BASELINE" ]]; then
  echo "Restore is unavailable because no pre-theme Herdr config was captured as a baseline." >&2
  exit 1
fi

mkdir -p "$STATE_DIR/backups" "$(dirname "$CONFIG_FILE")"
if [[ -f "$CONFIG_FILE" ]]; then
  install -m 600 "$CONFIG_FILE" "$STATE_DIR/backups/before-restore-$STAMP.toml"
fi
TMP="$CONFIG_FILE.restore.$$"
install -m 600 "$BASELINE" "$TMP"
mv "$TMP" "$CONFIG_FILE"

if ! "$HERDR" server reload-config; then
  echo "Baseline copied but Herdr rejected it; inspect $CONFIG_FILE." >&2
  exit 1
fi
printf 'Pre-theme Herdr config restored from %s\n' "$BASELINE"
