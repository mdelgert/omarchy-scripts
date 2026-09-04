# Task: script that runs a user-input command (default `omarchy commands --json`)

Status: In progress
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

- [ ] Running the script with the default value executes
      `omarchy commands --json` and pretty-prints the JSON result.
- [ ] Running it with a different typed command (including one with a
      pipe, e.g. `ls | wc -l`) executes that instead and shows its output.
- [ ] A failing command (non-zero exit, e.g. `false` or a typo'd binary)
      is clearly reported as failed, not silently ignored.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [ ] `docs/SCRIPT_SPEC.md`/`docs/ARCHITECTURE.md` updated only if this
      surfaces a new pattern worth documenting (e.g. "a script whose
      param is itself a shell command line is expected to use a shell to
      run it" — otherwise no doc changes are needed).

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

Fill in when finished: what changed, decisions made, limitations, and
useful follow-ups. Set Status to Done after merge, then move the
completed file to `docs/tasks/done/`.
