#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id hidden-example
# @script.title Hidden example
# @script.description Tagged "hidden" - should not appear in the Scripts menu's browse list or search, but still shows via `omarchy-scripts list`/`run`. See docs/SCRIPT_SPEC.md.
# @script.category Examples
# @script.icon \uf070
# @script.tags example,hidden

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

script_note "If you can see this in the menu's browse list, the 'hidden' tag isn't working."
