# Task: Script that updates every configurable `omarchy-scripts` setting

Status: Done
Type: feature
Claimed by: Copilot (@mdelgert_church) on 2026-09-03T19:47:29.490-07:00

## Problem

Today the only way to change `omarchy-scripts`' own settings
(`~/.config/omarchy-scripts/config.json`) is the CLI directly:
`config set/get/unset <dotted.path> <value>`, `config add-dir/remove-dir`.
That is fine for scripting, but there is no *script* — i.e. nothing that
shows up in the plugin's own menu with a param form — that lets a user
change settings from inside the running UI itself. Since scripts are
already how this project models "things a user can do with parameters,"
the natural way to expose settings-editing in the menu is a script whose
declared parameters are exactly the plugin's configurable values.

This script is meant to become **the** supported way end users update
configuration through the UI (as opposed to hand-editing
`config.json` or remembering CLI syntax), so it needs to cover
everything currently configurable, not just one arbitrary key:

- Every key binding action in `KEY_ACTION_DEFAULTS`
  (`moveUp`, `moveDown`, `open`, `quickRun`, `back`, `reload`, `run`,
  `edit`, `delete`) — see `src/omarchy_scripts/core.py`.
- `scriptDirs` — the list of extra script directories.

New configurable settings will be added over time (this is why
`generic-config-set-get-cli.md` built a generic mechanism instead of
one-off subcommands per key). This script's design must not require a
code change every time a new setting is added — see Scope below for how
it stays generic.

## Scope

- Add `scripts/examples/configure-omarchy-scripts.sh`: a single script
  that can update *any subset* of the currently configurable settings in
  one run, using the existing `omarchy-scripts config set/unset` CLI
  under the hood (do not reimplement settings I/O — this is the same
  lesson as `generic-config-set-get-cli.md`: one canonical mechanism).
  - Declare one optional string parameter per key action
    (`moveUp`, `moveDown`, `open`, `quickRun`, `back`, `reload`, `run`,
    `edit`, `delete`) plus one optional string parameter for
    `scriptDirs` (comma-separated list, matching how `add-dir`/`list-dirs`
    already present it).
  - Leave a parameter's underlying setting untouched when left blank —
    only call `config set`/`config unset` for values the user actually
    provided. An explicit sentinel (e.g. the literal word `default`) so
    a user can reset a key to its built-in default, or unset it via
    `config unset`.
  - After applying changes, print the full resolved configuration
    (e.g. via `config get keys` and `config get scriptDirs`, or a single
    `config get ""`/whole-file dump if the CLI supports it — check
    `generic-config-set-get-cli.md`'s Report for what the CLI actually
    supports) so the user sees the result of what they just changed.
  - Decide and document whether an empty/no-op run (no parameters
    filled in) should just print current values (safe, read-only) or
    be a no-op with a friendly message — this script is a **run**
    script, not check/apply/undo (v1 has no such protocol per
    `docs/VISION.md`), so there is no separate "preview" step; printing
    current values when nothing is provided is a reasonable substitute.
- If the current `config get`/`config set` CLI has any gaps that block
  this (e.g. no way to dump the whole file, no bulk-set), either extend
  the CLI minimally (reusing `_load_settings()`/`_write_settings()`) or
  fall back to calling `config get`/`set` once per field — prefer the
  smallest change that works.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly, matching the style of the existing
  example scripts.
- Add/extend a test in `tests/test_core.py` confirming the new script
  parses correctly and appears in `list`/`validate` output.
- Update the `## Example scripts` list in `README.md` with a one-line
  description, matching the existing entries' style.

## What done looks like

- [x] `scripts/examples/configure-omarchy-scripts.sh` exists, is
      executable, and parses via `./bin/omarchy-scripts list` /
      `validate` with no errors.
- [x] Running it with one or more parameters filled in updates exactly
      those settings in `~/.config/omarchy-scripts/config.json` and
      leaves everything else untouched.
- [x] Running it with a parameter set to `default` resets that setting
      to its built-in default (removes the override).
- [x] Running it with no parameters filled in prints the current full
      configuration without changing anything.
- [x] Invalid values (e.g. a bad key spec) surface the same error the
      underlying `config set` CLI already produces — no duplicated
      validation logic.
- [x] Tests are added or updated where behavior changed.
- [x] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [x] `README.md`'s Example scripts section documents the new script.

## Out of scope

- A generic script that edits arbitrary config files chosen by the user
  (any path, any format) — this task is scoped to `omarchy-scripts`' own
  settings only.
- Any check/apply/undo protocol — out of scope for v1 per
  `docs/VISION.md`.
- Automatically discovering *new* settings added in the future without
  a code change to this script — acceptable for this task to need a
  small follow-up edit when a brand-new setting category (not a new key
  action or a new script dir) is introduced later. Document this
  limitation in the Report.

## Testing notes

- Set two different key bindings and `scriptDirs` in one run; confirm
  all three land correctly and nothing else in `config.json` was
  touched.
- Reset one key binding to `default` and confirm it disappears from
  the `keys` object in `config.json` (falls back to the built-in
  default via `resolve_key_bindings()`).
- Run with everything blank and confirm it only prints, never writes.
- Confirm it still works when `~/.config/omarchy-scripts/config.json`
  does not exist yet (first run on a clean machine).

## Report

- Added `scripts/examples/configure-omarchy-scripts.sh`, an example/run
  script that declares one optional string parameter for every current key
  action plus `scriptDirs`. Non-empty values flow straight through the
  existing `omarchy-scripts config set/unset` CLI, so settings I/O and
  validation stay in the shared engine rather than being reimplemented in
  Bash.
- The script treats blank or omitted parameters as read-only/no-op for that
  field, and treats the literal value `default` as `config unset`. After
  every run — including an all-blank run — it prints the current resolved
  key bindings plus configured `scriptDirs`, so the menu form can double as
  a safe "show me the current settings" action.
- No CLI extension was needed for this task. The script prints the resolved
  keys by reusing `omarchy-scripts list` and prints `scriptDirs` via
  `omarchy-scripts config get scriptDirs`.
- Extended `tests/test_core.py` to cover the new script's metadata/CLI
  visibility, multi-setting updates that preserve unrelated existing
  settings, resetting a key binding back to default, blank read-only runs,
  and bubbling up the underlying invalid-key-spec error.
- Updated `README.md`'s example-scripts list with a one-line description of
  the new script.
- Verified with `make test`, `make lint-qml`, `make validate`,
  `./bin/omarchy-scripts validate`, and manual runs under an isolated
  project-local `XDG_CONFIG_HOME`. Manual checks confirmed that setting two
  key bindings plus `scriptDirs` updated only those entries, `default`
  removed the override from `keys`, and an all-blank run left the config
  file byte-for-byte unchanged while printing the resolved configuration.
- Limitation kept intentionally in scope with the task: if a future release
  adds a brand-new setting category beyond today's key actions and
  `scriptDirs`, this script will need a small follow-up edit to expose that
  new category as additional declared parameters.
