#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id check-website-status
# @script.title Check website status
# @script.description Curls a URL, prints its HTTP status and headers, and pretty-prints the JSON body if there is one.
# @script.category Networking
# @script.icon \uf0ac
# @script.tags network,http,json
# @param url string required=true default=https://httpbin.org/json label="URL to check"
# @param method choice default=GET choices=GET,HEAD,POST label="HTTP method"

# This is the shape the first user request asked about: a "run" script, not a
# check/apply pair. There is nothing to undo — running it again just checks
# again — so it declares no undo and none is expected. See docs/VISION.md.

source "${OMARCHY_SCRIPTS_LIB:?}/scripts.sh"
script_parse_args "$@"

url="${SCRIPT_ARG_URL}"
method="${SCRIPT_ARG_METHOD:-GET}"

script_note "Requesting: ${method} ${url}"

response="$(curl -sS -D - -o /tmp/check-website-status.body -w '\n%{http_code}\n%{time_total}s\n' \
  -X "$method" "$url")"

headers="$(printf '%s\n' "$response" | sed '$d;$d')"
status="$(printf '%s\n' "$response" | tail -2 | head -1)"
elapsed="$(printf '%s\n' "$response" | tail -1)"

echo "Status: ${status}"
echo "Time:   ${elapsed}"
echo
echo "Headers:"
printf '%s\n' "$headers"
echo

if [[ -s /tmp/check-website-status.body ]] && jq -e . /tmp/check-website-status.body >/dev/null 2>&1; then
  echo "Body (JSON):"
  jq . /tmp/check-website-status.body
else
  echo "Body (not JSON, first 20 lines):"
  head -20 /tmp/check-website-status.body 2>/dev/null || true
fi
rm -f /tmp/check-website-status.body
