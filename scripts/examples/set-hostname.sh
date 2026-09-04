#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id set-hostname
# @script.title Set hostname
# @script.description Changes the machine's hostname via hostnamectl. Re-run with the previous value to revert.
# @script.category System
# @script.icon \uf2db
# @script.tags system,network,hostname
# @param hostname string required=true label="New hostname"
# @script.tags hidden

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

new_hostname="${SCRIPT_ARG_HOSTNAME:-}"

script_note "Current hostname: $(hostname)"

# Plain sanity check, not a full RFC 1123 validation: reject empty values and
# anything containing whitespace or a slash (values that would obviously
# break `hostnamectl` or downstream tooling).
if [[ -z "$new_hostname" ]] || [[ "$new_hostname" =~ [[:space:]/] ]]; then
  echo "Invalid hostname: '$new_hostname' (must be non-empty, no spaces or slashes)" >&2
  exit 1
fi

if ! command -v hostnamectl >/dev/null 2>&1; then
  echo "hostnamectl not found; this script requires a systemd-based system" >&2
  exit 1
fi

set +e
hostnamectl_output="$(hostnamectl set-hostname "$new_hostname" 2>&1)"
hostnamectl_status=$?
set -e

if [[ $hostnamectl_status -ne 0 ]]; then
  echo "Failed to set hostname: $hostnamectl_output" >&2
  echo "This usually means insufficient privileges. Try running this script with sudo," >&2
  echo "or note that a polkit authentication prompt may be required and this execution" >&2
  echo "environment may not support interactive prompts." >&2
  exit 1
fi

script_note "New hostname: $(hostname)"
