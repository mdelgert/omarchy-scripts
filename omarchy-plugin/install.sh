#!/usr/bin/env bash
# Install this working tree as an Omarchy plugin and reload the shell.
#
# For a normal install, prefer:
#
#   omarchy plugin add https://github.com/mdelgert/omarchy-scripts.git --enable
#
# which clones the repository straight into the plugins directory. This script
# is the development equivalent: it copies the working tree, uncommitted
# changes and all, so you can iterate without pushing.
#
# Re-run after editing. Set OMARCHY_SCRIPTS_BIN to point the plugin at a
# different runner instead, when iterating on the engine alone.
set -Eeuo pipefail

PLUGIN_ID=io.github.mdelgert.omarchy-scripts
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

mkdir -p "$DEST"

rsync -a --delete \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude '.qml-imports/' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  "$SRC/" "$DEST/"

printf 'installed %s -> %s\n' "$PLUGIN_ID" "$DEST"

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$DEST" || { printf 'manifest validation failed\n' >&2; exit 1; }
  printf 'manifest validated\n'
fi

"$DEST/bin/omarchy-scripts" validate >/dev/null || {
  printf 'installed scripts failed validation\n' >&2
  exit 1
}
printf 'scripts validated\n'

# Materializes config.json with every key-action default and an empty
# scriptDirs on a fresh install, so "where do my settings live" has a real
# file to answer it from day one. Safe to re-run on every install/update:
# it only fills in keys genuinely missing, never touches anything already
# customized there.
"$DEST/bin/omarchy-scripts" config init >/dev/null || {
  printf 'could not materialize config.json\n' >&2
  exit 1
}
printf 'config.json ready\n'

# rescanPlugins re-walks the plugin directories and hot-reloads plugin code.
# It needs a running shell; outside a session this is expected to fail.
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 \
    && printf 'shell reloaded\n' \
    || printf 'could not reach omarchy-shell (is the shell running?)\n' >&2
fi

cat <<EOF

Enable and open it with:
  omarchy plugin enable $PLUGIN_ID right
  omarchy-shell shell toggle $PLUGIN_ID '{}'
EOF
