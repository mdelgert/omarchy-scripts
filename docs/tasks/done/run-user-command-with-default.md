# Task: script that runs a user-input command (default `omarchy commands --json`)

Status: Done
Type: feature

## Problem

There's no example script that just runs an arbitrary command the user
types in, with a sensible default. A natural first default is
`omarchy commands --json` — handy for exploring what other `omarchy` CLI
commands exist, in JSON form, without leaving the menu.

## Scope

- Add `scripts/examples/run-command.sh`:
  - `@script.id run-command`, category something like `Utility` or `System`.
  - One `@param command string required=true default="omarchy commands --json" label="Command to run"`.
  - Runs the typed command and prints its stdout/stderr/exit code. Since
    the whole point of this script is executing a user-authored shell
    command line (pipes, quotes, flags — not a single argv token), it
    necessarily runs it via a shell (e.g. `bash -c "$command"`), the same
    trust model as a user typing directly into a terminal. This is
    *not* the same thing AGENTS.md's "no `shell=True`, no argv assembled
    from metadata" rule forbids — that rule is about the engine
    (`core.py`/QML) building shell strings out of script *metadata* or
    other values it doesn't control; here the single param's whole
    purpose is to be a shell command line the user themselves typed for
    this one run.
  - If the output is valid JSON (as the default `omarchy commands --json`
    would produce), pretty-print it with `jq` (mirroring
    `check-website-status.sh`'s JSON-body handling); otherwise print raw
    output.
  - Non-zero exit codes should be surfaced clearly (e.g. via
    `script_note`/exit status), not swallowed.
- Follow the existing example-script conventions: `scripts.sh` helpers
  (`script_parse_args`, `SCRIPT_ARG_*`), `set -Eeuo pipefail`, a run-only
  script (no undo needed — running it again just re-runs the command).

## What done looks like

- [x] Running the script with the default value executes
      `omarchy commands --json` and pretty-prints the JSON result.
- [x] Running it with a different typed command (including one with a
      pipe, e.g. `ls | wc -l`) executes that instead and shows its output.
- [x] A failing command (non-zero exit, e.g. `false` or a typo'd binary)
      is clearly reported as failed, not silently ignored.
- [x] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [x] `docs/SCRIPT_SPEC.md`/`docs/ARCHITECTURE.md` updated only if this
      surfaces a new pattern worth documenting (e.g. "a script whose
      param is itself a shell command line is expected to use a shell to
      run it" — otherwise no doc changes are needed). Documented in
      `docs/SCRIPT_SPEC.md` ("Attribute values are data, not shell") during
      post-merge review; the script is also listed in `README.md`.

## Out of scope

- Any sandboxing, allow-listing, or confirmation dialog before running the
  typed command — the user typing it is the confirmation, same as a
  terminal prompt.
- Making this pattern (a shell-command-line param) a first-class
  `@param` type in `core.py`/`Menu.qml` — it's just a `string` param whose
  value happens to be a shell command line; no engine changes are needed.

## Testing notes

- Verify live via `omarchy-restart-shell` / `omarchy-shell shell toggle`
  that the field's default shows `omarchy commands --json` (as
  placeholder or prefilled default text, whichever this repo's current
  `default=`-on-load convention is for single-run scripts — see
  `configure-omarchy-scripts.sh`'s task history for why `default=` is
  *not* safe on multi-field "settings" scripts, which doesn't apply here
  since this is a single-field run-once script, not a leave-blank-to-skip
  settings form).
- Confirm both a JSON-producing command and a plain-text command render
  sensibly.

## Report

**Changed:** added `scripts/examples/run-command.sh` — a single-param
(`command`, default `omarchy commands --json`) run-only script. Runs the
typed command via `bash -c "$command"` (the shell-command-line trust model
described in Scope), captures stdout+stderr together to a temp file,
pretty-prints with `jq` if the output parses as JSON (mirroring
`check-website-status.sh`), otherwise prints it raw, then reports the exit
status clearly and re-exits non-zero on failure so a failing command is
never silently swallowed.

**Verified:**
- Via the CLI directly (`./bin/omarchy-scripts run run-command`):
  - Default value runs `omarchy commands --json` and pretty-prints the
    JSON result.
  - `--param command="ls | wc -l"` (a pipe) runs correctly through the
    shell and prints its (single-number, still valid-JSON) output.
  - `--param command=false` and a typo'd binary both report a non-zero
    exit status (1 and 127 respectively) and the script's own exit code
    matches, without swallowing the failure.
- Live in a real Hyprland/quickshell session: installed the branch,
  restarted the shell, filtered the menu to "run" and confirmed
  "Run a command" appears under a new "Utility" category with the
  `command` field prefilled with the default value, matching this repo's
  existing default-prefill convention for single-run scripts. Restored the
  live session to `main`'s build afterward.
- `make test` (47/47 passing, no new tests needed — pure shell script, no
  Python-level surface, same rationale as `check-website-status.sh`),
  `make lint-qml` (same 4 documented warning categories, no new one),
  `make validate` (0 problems, 8 scripts now).

**Limitations:** as in a prior task's Report, this sandbox's `hyprctl
dispatch` shim and lack of `ydotool`/pointer control meant I could type into
the on-screen field (`wtype`) but could not reliably click "Run" or
tab-navigate to it from the keyboard-only script metadata form; the menu
closed itself during one such attempt rather than executing the script.
This is a sandbox interaction limitation, not a script bug — the exact same
script logic was fully exercised (default, pipe, and two failure cases) via
the CLI, which runs the identical code path the QML action invokes.

**Follow-ups:** none identified.
