# lib/scripts.sh — the one helper an omarchy-scripts script may use
#
# Optional, not required. A script is a plain executable; nothing forces you
# to source this file, and nothing here does anything a script couldn't do
# in three lines itself. It exists purely to remove one piece of repeated
# boilerplate: turning `--name value` pairs back into shell variables.
#
# Usage:
#   source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
#   script_parse_args "$@"
#   echo "$SCRIPT_ARG_NAME"
#
# `OMARCHY_SCRIPTS_LIB` is set by the engine before it runs a script, so a
# script never has to guess its own location.

# Parse `--name value` pairs into `SCRIPT_ARG_NAME` variables (dashes become
# underscores, name is uppercased). Unknown-flag or missing-value input is a
# caller bug, not a runtime condition to recover from, so this returns
# non-zero rather than guessing.
script_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --*)
        local name="${1#--}"
        local var
        var="SCRIPT_ARG_$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
        if [[ $# -lt 2 ]]; then
          printf 'script_parse_args: missing value for --%s\n' "$name" >&2
          return 1
        fi
        printf -v "$var" '%s' "$2"
        shift 2
        ;;
      *)
        printf 'script_parse_args: unexpected argument: %s\n' "$1" >&2
        return 1
        ;;
    esac
  done
}

# A one-line, human-readable status line. Purely a convenience for
# consistent-looking output — nothing parses or requires it.
script_note() {
  printf '%s\n' "$*"
}
