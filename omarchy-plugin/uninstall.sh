#!/usr/bin/env bash
# Remove the dev install created by omarchy-plugin/install.sh and restart
# the shell so it disappears immediately.
#
# By default this only removes the installed plugin itself — never your
# workspace scripts or settings file (${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}),
# since those are yours, not the plugin's. Pass --purge-workspace to also
# delete that directory; there is no separate confirmation prompt for it,
# so only pass it when you actually mean to throw that away.
set -Eeuo pipefail

PLUGIN_ID=io.github.mdelgert.omarchy-scripts
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
WORKSPACE="${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-scripts}"

PURGE_WORKSPACE=0
for arg in "$@"; do
  case "$arg" in
  --purge-workspace) PURGE_WORKSPACE=1 ;;
  *)
    printf 'unknown option: %s\n' "$arg" >&2
    exit 1
    ;;
  esac
done

if [[ ! -e $DEST && ! -L $DEST ]]; then
  printf '%s is not installed at %s\n' "$PLUGIN_ID" "$DEST"
else
  # Prefer Omarchy's own plugin removal (handles disabling it in the shell's
  # config first, not just deleting files) over reimplementing that here.
  # --yes: this script has no interactive prompt of its own, matching how
  # install.sh never asks for confirmation either.
  #
  # omarchy-plugin-remove hardcodes $HOME/.config rather than honoring a
  # customized XDG_CONFIG_HOME, so it can fail here even though $DEST (which
  # does honor it, matching install.sh) genuinely exists. Any failure falls
  # through to a direct removal of the one path this script itself resolved,
  # rather than aborting the whole script — an uninstall should not get
  # stuck just because the shared tool's own path assumptions don't match.
  if command -v omarchy-plugin-remove >/dev/null 2>&1 \
    && omarchy-plugin-remove "$PLUGIN_ID" --yes; then
    printf 'removed %s\n' "$PLUGIN_ID"
  else
    rm -rf -- "$DEST"
    printf 'removed %s -> %s\n' "$PLUGIN_ID" "$DEST"
  fi
fi

if (( PURGE_WORKSPACE )); then
  if [[ -e $WORKSPACE || -L $WORKSPACE ]]; then
    rm -rf -- "$WORKSPACE"
    printf 'purged workspace %s\n' "$WORKSPACE"
  else
    printf 'no workspace to purge at %s\n' "$WORKSPACE"
  fi
fi

# Same non-fatal-outside-a-session guard as install.sh's own restart step.
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 \
    && printf 'shell restarted\n' \
    || printf 'could not restart the shell (is a session running?)\n' >&2
fi
