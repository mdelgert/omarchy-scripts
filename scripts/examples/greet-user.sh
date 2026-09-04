#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id greet-user
# @script.title Greet a user
# @script.description Minimal example showing how declared parameters arrive as shell variables.
# @script.category Examples
# @script.icon \uf0eb
# @script.tags example
# @param name string required=true default=friend label="Name to greet"
# @param shout boolean default=false label="ALL CAPS"

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

message="Hello, ${SCRIPT_ARG_NAME}!"
if [[ "${SCRIPT_ARG_SHOUT:-false}" == "true" ]]; then
  message="$(printf '%s' "$message" | tr '[:lower:]' '[:upper:]')"
fi
script_note "$message"
