#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id script-capability-showcase
# @script.title Script capability showcase
# @script.description Demonstrates every v1 parameter type with safe, visible defaults.
# @script.category Examples
# @script.icon \uf085
# @script.tags example,demo,parameters
# @param message string default="Hello from omarchy-scripts!" label="Message to repeat"
# @param count integer default=3 min=1 max=10 label="Number of repetitions"
# @param enabled boolean default=true label="Enable the feature"
# @param format choice default=summary choices=summary,details label="Display format"
# @param output path default=. label="Output destination (display only)"

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

message="${SCRIPT_ARG_MESSAGE}"
count="${SCRIPT_ARG_COUNT}"
enabled="${SCRIPT_ARG_ENABLED}"
format="${SCRIPT_ARG_FORMAT}"
output="${SCRIPT_ARG_OUTPUT}"

script_note "Script capability showcase"
printf 'message: %s\n' "$message"
printf 'count: %s\n' "$count"
printf 'enabled: %s\n' "$enabled"
printf 'format: %s\n' "$format"
printf 'output: %s\n' "$output"
printf '\nRepeated message:\n'

for ((index = 1; index <= count; index++)); do
  printf '%d. %s\n' "$index" "$message"
done

if [[ "$enabled" == "true" ]]; then
  script_note "Feature status: enabled"
else
  script_note "Feature status: disabled"
fi

if [[ "$format" == "details" ]]; then
  printf '\nDetails:\n'
  printf 'The displayed output destination is: %s\n' "$output"
  printf 'No files were created or changed.\n'
fi
