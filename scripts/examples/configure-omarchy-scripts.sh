#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id configure-omarchy-scripts
# @script.title Configure omarchy-scripts
# @script.description Updates omarchy-scripts key bindings and extra script directories, then prints the full configuration.
# @script.category Examples
# @script.icon \uf013
# @script.tags config,example
# @param scriptDirs string placeholder="(none)" label="Extra script directories, comma-separated (blank leaves unchanged; 'default' resets to none)"
# @param moveUp string placeholder="Up" label="moveUp key (blank leaves unchanged; type 'default' to reset)"
# @param moveDown string placeholder="Down" label="moveDown key (blank leaves unchanged; type 'default' to reset)"
# @param open string placeholder="Return" label="open key (blank leaves unchanged; type 'default' to reset)"
# @param quickRun string placeholder="Shift+Return" label="quickRun key (blank leaves unchanged; type 'default' to reset)"
# @param back string placeholder="Escape" label="back key (blank leaves unchanged; type 'default' to reset)"
# @param reload string placeholder="F5" label="reload key (blank leaves unchanged; type 'default' to reset)"
# @param run string placeholder="R" label="run key (blank leaves unchanged; type 'default' to reset)"
# @param edit string placeholder="E" label="edit key (blank leaves unchanged; type 'default' to reset)"
# @param delete string placeholder="D" label="delete key (blank leaves unchanged; type 'default' to reset)"

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

runner="${OMARCHY_SCRIPTS_ROOT:?}/bin/omarchy-scripts"

apply_setting() {
  local path="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    return
  fi

  if [[ "$value" == "default" ]]; then
    "$runner" config unset "$path" >/dev/null
  else
    "$runner" config set "$path" "$value" >/dev/null
  fi
}

apply_script_dirs() {
  local value="$1"
  local json_value

  if [[ -z "$value" ]]; then
    return
  fi

  if [[ "$value" == "default" ]]; then
    "$runner" config unset scriptDirs >/dev/null
    return
  fi

  json_value="$(python3 - "$value" <<'PY'
import json
import sys

print(json.dumps([part.strip() for part in sys.argv[1].split(",") if part.strip()]))
PY
)"
  "$runner" config set scriptDirs "$json_value" >/dev/null
}

print_configuration() {
  python3 - "$runner" <<'PY'
import json
import subprocess
import sys

runner = sys.argv[1]
list_data = json.loads(subprocess.check_output([runner, "list"], text=True))
dirs_data = json.loads(
    subprocess.check_output([runner, "config", "get", "scriptDirs"], text=True)
)

result = {
    "configPath": dirs_data["configPath"],
    "keys": list_data["keys"],
    "scriptDirs": dirs_data["value"] or [],
}
if list_data.get("settingsProblems"):
    result["settingsProblems"] = list_data["settingsProblems"]

print(json.dumps(result, indent=2))
PY
}

apply_script_dirs "${SCRIPT_ARG_SCRIPTDIRS-}"
apply_setting "keys.moveUp" "${SCRIPT_ARG_MOVEUP-}"
apply_setting "keys.moveDown" "${SCRIPT_ARG_MOVEDOWN-}"
apply_setting "keys.open" "${SCRIPT_ARG_OPEN-}"
apply_setting "keys.quickRun" "${SCRIPT_ARG_QUICKRUN-}"
apply_setting "keys.back" "${SCRIPT_ARG_BACK-}"
apply_setting "keys.reload" "${SCRIPT_ARG_RELOAD-}"
apply_setting "keys.run" "${SCRIPT_ARG_RUN-}"
apply_setting "keys.edit" "${SCRIPT_ARG_EDIT-}"
apply_setting "keys.delete" "${SCRIPT_ARG_DELETE-}"

print_configuration
