#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id reinstall-from-source
# @script.title Reinstall plugin from source
# @script.description Reinstalls the plugin from a separate source checkout; targeting the same copy is a no-op self-copy.
# @script.category Development
# @script.icon \uf021
# @script.tags development,install,plugin
# @param path path label="Source checkout directory (defaults to config devSourcePath if omitted)"

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

configured_source_path() {
  env PYTHONPATH="${OMARCHY_SCRIPTS_ROOT:?}/src:${PYTHONPATH:-}" python3 - <<'PY'
from omarchy_scripts import core
import sys

try:
    value = core.get_config_value("devSourcePath")
except core.ScriptError as exc:
    print(exc, file=sys.stderr)
    raise SystemExit(2)

if isinstance(value, str) and value.strip():
    print(value)
PY
}

normalize_path() {
  env PYTHONPATH="${OMARCHY_SCRIPTS_ROOT:?}/src:${PYTHONPATH:-}" python3 - "$1" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).expanduser().resolve(strict=False))
PY
}

source_root="${SCRIPT_ARG_PATH-}"
if [[ -z "$source_root" ]]; then
  source_root="$(configured_source_path)"
  if [[ -z "$source_root" ]]; then
    echo "path is required unless config devSourcePath is set" >&2
    exit 1
  fi
  script_note "Using configured devSourcePath: $source_root"
fi

source_root="$(normalize_path "$source_root")"
install_script="$source_root/omarchy-plugin/install.sh"

if [[ ! -d "$source_root" ]]; then
  echo "source checkout directory does not exist: $source_root" >&2
  exit 1
fi

if [[ ! -f "$install_script" ]]; then
  echo "source checkout must contain omarchy-plugin/install.sh: $source_root" >&2
  exit 1
fi

# This script wraps the normal development reinstall path. When the installed
# plugin copy targets itself rather than a separate checkout, rsync has nothing
# new to copy in; the useful case is a stale installed copy pointing at a newer
# source tree elsewhere.
exec "$install_script"
