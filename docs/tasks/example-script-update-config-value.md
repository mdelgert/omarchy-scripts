# Task: Example script that updates a configuration value

Status: Ready
Type: feature

## Problem

The example scripts under `scripts/examples/` currently show a read-only
diagnostic script (`hostname-info.sh`), a pure-parameter demo
(`greet-user.sh`), and a bounded-integer/path demo
(`largest-directories.sh`). None of them demonstrate the common
professional use case of **changing a configuration value on disk** —
e.g. flipping a setting in an INI/conf file, a dotted key in a JSON file,
or an environment-style `KEY=value` file. This is one of the most common
real-world sysadmin/dev scripts (toggling a service option, changing a
port, enabling a feature flag) and there is no example showing how such a
script should declare its parameters and describe itself so it shows up
correctly in the menu.

This also doubles as a natural demonstration script for
`omarchy-scripts`' own `config set/get/unset` CLI (added in
`generic-config-set-get-cli.md`) — the example can literally shell out to
`omarchy-scripts config set <path> <value>` to update this plugin's own
`~/.config/omarchy-scripts/config.json`, giving users something they can
run immediately with no external files to point at.

## Scope

- Add `scripts/examples/update-config-value.sh`: a script that updates one
  key in `~/.config/omarchy-scripts/config.json` using the existing
  `omarchy-scripts config set <dotted.path> <value>` CLI, so it works
  out of the box against real state and needs no fixture file.
  - Declare two required string parameters: the dotted key path (e.g.
    `keys.moveDown`) and the new value.
  - Print the before/after value (via `config get`) so the user can see
    the effect, similar to how `hostname-info.sh` prints diagnostic
    output.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly, matching the style of the other example
  scripts.
- This is a **run** script, not a check/apply/undo recipe: v1 has no such
  protocol (see `docs/VISION.md`), so the script just performs the change
  each time it is run. No undo is required or expected.
- Add/extend a test in `tests/test_core.py` (or wherever the existing
  example scripts are validated/discovered) confirming the new script
  parses correctly and appears in `list`/`validate` output, following the
  same pattern used for the other three example scripts.
- Update the `## Example scripts` list in `README.md` with a one-line
  description, matching the existing three entries' style.

## What done looks like

- [ ] `scripts/examples/update-config-value.sh` exists, is executable,
      and parses via `./bin/omarchy-scripts list` / `validate` with no
      errors.
- [ ] Running it with a real dotted path and value updates
      `~/.config/omarchy-scripts/config.json` and prints the old and new
      value.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [ ] `README.md`'s Example scripts section documents the new script.

## Out of scope

- A generic script that edits *arbitrary* config files chosen by the
  user (any path, any format) — this would need its own parsing/format
  logic and is a separate, larger task if wanted later. This task is
  scoped to demonstrating the pattern against `omarchy-scripts`' own
  config, which already has a safe, tested CLI to shell out to.
- Any check/apply/undo protocol — out of scope for v1 per
  `docs/VISION.md`.

## Testing notes

- Run the script twice with different values for the same key and
  confirm the "before" value printed on the second run matches the
  "after" value printed on the first run.
- Confirm it rejects an invalid value the same way
  `omarchy-scripts config set` already does (e.g. an invalid key spec
  under `keys.*`), so error handling isn't duplicated — just let the
  underlying CLI's exit code/error surface through.
- Confirm the script still works when `~/.config/omarchy-scripts/config.json`
  does not exist yet (first run on a clean machine).

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
