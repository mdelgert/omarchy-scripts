#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id run-command
# @script.title Run a command
# @script.description Runs a typed shell command line and pretty-prints its output; pretty-prints JSON if the output is JSON.
# @script.category Utility
# @script.icon \uf120
# @script.tags shell,command,json
# @param command string required=true default="omarchy commands --json" label="Command to run"

# This is a "run" script, not a check/apply pair — there is nothing to undo,
# running it again just runs the command again. See docs/VISION.md.
#
# The whole point of this script is to execute a shell command line the user
# themselves typed for this one run (pipes, quotes, flags and all) — it is
# not a single argv token, so it necessarily goes through a shell
# (`bash -c "$command"`), the same trust model as typing directly into a
# terminal. This is not what AGENTS.md's "no shell=True, no argv assembled
# from metadata" rule forbids: that rule is about the engine (core.py/QML)
# building shell strings out of script *metadata* or other values it does
# not control. Here there is exactly one param, and its only purpose is to
# be a shell command line the user chose to run.

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

command="${SCRIPT_ARG_COMMAND}"

script_note "Running: ${command}"
echo

out_file="$(mktemp)"
trap 'rm -f "$out_file"' EXIT

status=0
bash -c "$command" >"$out_file" 2>&1 || status=$?

if [[ -s "$out_file" ]] && jq -e . "$out_file" >/dev/null 2>&1; then
  echo "Output (JSON):"
  jq . "$out_file"
else
  echo "Output:"
  cat "$out_file"
fi

echo
if [[ $status -eq 0 ]]; then
  script_note "Exit status: ${status} (success)"
else
  script_note "Exit status: ${status} (failed)"
  exit "$status"
fi
