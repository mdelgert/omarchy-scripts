#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id show-config
# @script.title Show config
# @script.description Prints the current omarchy-scripts config.json contents (configVersion, keys, scriptDirs) read-only.
# @script.category Examples
# @script.icon \uf085
# @script.tags config,example

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

runner="${OMARCHY_SCRIPTS_ROOT:?}/bin/omarchy-scripts"

python3 - "$runner" <<'PY'
import json
import subprocess
import sys

runner = sys.argv[1]
list_data = json.loads(subprocess.check_output([runner, "list"], text=True))
version_data = json.loads(
    subprocess.check_output([runner, "config", "get", "configVersion"], text=True)
)
dirs_data = json.loads(
    subprocess.check_output([runner, "config", "get", "scriptDirs"], text=True)
)

result = {
    "configPath": version_data["configPath"],
    "configVersion": version_data["value"],
    "keys": list_data["keys"],
    "scriptDirs": dirs_data["value"] or [],
}
if list_data.get("settingsProblems"):
    result["settingsProblems"] = list_data["settingsProblems"]

print(json.dumps(result, indent=2))
PY
