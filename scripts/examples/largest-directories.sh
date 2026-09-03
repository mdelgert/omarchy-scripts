#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id largest-directories
# @script.title Largest directories
# @script.description Lists the N largest directories under a given path.
# @script.category Diagnostics
# @script.tags disk,diagnostics
# @param path path label="Directory to scan (default: your home directory)"
# @param count integer default=10 min=1 max=50 label="How many to show"

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

# The metadata default for `count` is a plain literal, so it's always safe to
# use directly. `path` has no metadata default on purpose: `$HOME` needs to be
# expanded by this shell at run time, not stored as a literal string in a
# comment the parser never executes.
target="${SCRIPT_ARG_PATH:-$HOME}"
count="${SCRIPT_ARG_COUNT:-10}"

if [[ ! -d "$target" ]]; then
  echo "not a directory: $target" >&2
  exit 1
fi

du -h --max-depth=1 -- "$target" 2>/dev/null | sort -rh | head -n "$count"
