#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id run-command
# @script.title Run a command
# @script.description Runs a typed shell command line and pretty-prints its output; pretty-prints JSON if the output is JSON.
# @script.category Utility
# @script.icon \uf120
# @script.tags shell,command,json
# @param command string required=true default="omarchy commands --json" label="Command to run"

# Run-only script: nothing to undo, running it again just runs the command
# again (see docs/VISION.md). The single param *is* a shell command line the
# user typed, so it deliberately runs via `bash -c` -- the same trust model as
# a terminal. See "Attribute values are data, not shell" in docs/SCRIPT_SPEC.md
# for why this does not conflict with the engine-side argv rule in AGENTS.md.

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

command="${SCRIPT_ARG_COMMAND}"

# The engine's required=true only rejects an omitted param, not a field the
# user cleared, so a blank command must be refused here rather than run as a
# silent no-op that reports success.
if [[ -z "${command//[[:space:]]/}" ]]; then
  echo "run-command: no command given" >&2
  exit 2
fi

script_note "Running: ${command}"
echo

# Only stdout is captured (so a stderr warning cannot break JSON detection and
# the engine still records stderr separately); stdin is closed so a command
# that waits for input fails fast instead of hanging until the engine timeout.
status=0
out="$(bash -c "$command" </dev/null)" || status=$?

# Pretty-print only when the whole output is exactly one JSON object or array.
# `jq -e .` alone would also accept bare scalars and multi-value streams, so
# `ls | wc -l` or `seq 3` would be mislabelled as JSON.
if pretty="$(jq -s 'if length == 1 and (.[0] | type == "object" or type == "array") then .[0] else error("not a JSON document") end' <<<"$out" 2>/dev/null)"; then
  echo "Output (JSON):"
  out="$pretty"
else
  echo "Output:"
fi

# The engine stores the full output in last-run and the menu lays it all out
# on every selection, so a runaway command must not produce megabytes here.
max_chars=262144
if (( ${#out} > max_chars )); then
  printf '%s\n' "${out:0:max_chars}"
  script_note "... (truncated: showing the first ${max_chars} of ${#out} characters)"
elif [[ -n "$out" ]]; then
  printf '%s\n' "$out"
fi

echo
verdict=success
[[ $status -eq 0 ]] || verdict=failed
script_note "Exit status: ${status} (${verdict})"
exit "$status"
