# Task: add a `configVersion` value to config.json, and a script that reads it

Status: Done
Type: feature

## Problem

`config.json` (materialized by `materialize_default_config()`,
`core.py:294-324`) currently only ever gets a `keys` object and a
`scriptDirs` array — there's no version stamp on the config file itself,
so a future change to its shape has nothing to detect "this file predates
the new shape" from. Separately, there's no way to see the file's current
contents from inside the menu (only `configure-omarchy-scripts.sh`, which
is a *write*-oriented settings form, not a read/inspect view) — a user has
to `cat ~/.config/omarchy-scripts/config.json` in a terminal to check it.

Note: don't confuse this with the CLI response envelope's existing
`schemaVersion` (`cli.py:27`, `ScriptEngine.qml:19`) — that versions the
*CLI's JSON output contract* and is unrelated. This task is about a
version stamp inside the persisted `config.json` file's own content, so
call it `configVersion` to keep the two clearly distinct.

## Scope

- In `core.py`, add a `configVersion` constant (start at `1`) and have
  `materialize_default_config()` fill it in the same "only if missing,
  never overwrite" way it already does for `keys`/`scriptDirs` — an
  existing `config.json` without it gets it added; an existing value is
  left alone (relevant once/if a real migration is ever needed).
- Add `scripts/examples/show-config.sh`: a plain read-only script (no
  `@param`s) that reads and pretty-prints the current `config.json`
  contents, including `configVersion`, `keys`, and `scriptDirs` — via
  `omarchy-scripts config get` (or by reading the file path directly,
  whichever is simpler and doesn't duplicate path-resolution logic
  `core.py` already owns; prefer going through the CLI/`core` rather than
  hardcoding `~/.config/omarchy-scripts/config.json` in the script).
  This is a read-only counterpart to `configure-omarchy-scripts.sh`, not
  a replacement for it.
- Update the relevant test(s) in `tests/test_core.py` that assert on
  `materialize_default_config()`'s resulting keys/shape.

## What done looks like

- [ ] A fresh `config init` (or a fresh plugin install, which calls it)
      produces a `config.json` containing `configVersion: 1` alongside
      the existing `keys`/`scriptDirs`.
- [ ] Running `config init` again on an already-materialized file with a
      hand-edited `configVersion` value does not overwrite that value —
      matching the existing "only fill in what's missing" contract.
- [ ] The new `show-config.sh` script prints the current config contents,
      verified live via `omarchy-restart-shell` / `omarchy-shell shell
      toggle`, not just by reading the code.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [ ] `docs/SCRIPT_SPEC.md`/`docs/ARCHITECTURE.md` updated if they
      document `config.json`'s shape (check whether they already list
      `keys`/`scriptDirs` and add `configVersion` alongside them if so).

## Out of scope

- Any actual migration logic that reads/transforms an old-shaped
  `config.json` into a new one — `configVersion` is only a stamp for a
  *future* task to key off of; there is nothing to migrate yet.
- Changing the CLI response envelope's existing `schemaVersion` — that's
  a separate, already-shipped contract and must not be touched.
- Turning `show-config.sh` into a settings editor — that's what
  `configure-omarchy-scripts.sh` already does; this task is read-only.

## Testing notes

- Delete/rename any local `config.json`, run `config init`, confirm
  `configVersion: 1` appears.
- Hand-edit `configVersion` to a different number, re-run `config init`,
  confirm it's left untouched (only genuinely missing keys are filled).
- Run `show-config.sh` from the menu and confirm the printed contents
  match the actual file on disk.

## Report

**What changed:**

- `core.py`: added `CONFIG_VERSION = 1` (distinct constant from the
  existing `SCHEMA_VERSION`, with a comment explicitly pointing out the
  difference). `materialize_default_config()` now fills in
  `configVersion` the same "only if missing" way it already fills in
  `keys`/`scriptDirs` — an existing value (however weird) is never
  touched on a later `config init`.
- `cli.py`: `config init`'s JSON response now also reports the resulting
  `configVersion` alongside `changed`/`keys`/`scriptDirs`.
- `scripts/examples/show-config.sh` (new): a plain read-only script (no
  `@param`s) that shells out to the same `omarchy-scripts` runner
  (`list`, `config get configVersion`, `config get scriptDirs`) and
  pretty-prints `configPath`, `configVersion`, `keys`, and `scriptDirs`
  — modeled directly on `configure-omarchy-scripts.sh`'s existing
  `print_configuration` helper, so it goes through the CLI rather than
  reading `~/.config/omarchy-scripts/config.json` directly.
- `tests/test_core.py`: updated the fresh-install/idempotent
  `config init` assertions to expect `configVersion: 1`, and added
  `test_config_init_never_overwrites_existing_configVersion` (hand-sets
  `configVersion: 999`, re-runs `config init`, confirms it survives
  untouched).
- `docs/ARCHITECTURE.md`/`docs/SCRIPT_SPEC.md`: documented `configVersion`
  alongside `keys`/`scriptDirs`/`devSourcePath` in the settings-file
  shape and schema list, and noted it's distinct from `schemaVersion`
  (the CLI's JSON-output-contract stamp, unrelated and untouched).

**Decisions:**

- Went through the CLI (`config get`) in `show-config.sh` rather than
  reading `config.json` directly, per the task's stated preference —
  keeps path-resolution logic solely owned by `core.py`.
- No migration logic was added (out of scope per the task) —
  `configVersion` is purely a stamp for a future change to key off of.

**Verification:**

- `make test` (52/52, including the two updated tests and the one new
  test), `make lint-qml` (only the four pre-existing allowed warning
  categories), `make validate` (11 scripts, 0 problems — confirms the
  new `show-config.sh` parses cleanly).
- Manually confirmed via the CLI directly: a fresh `config init` in a
  scratch `OMARCHY_SCRIPTS_HOME` produces `configVersion: 1`; hand-setting
  it to `999` and re-running `config init` leaves it at `999`.
- Verified live, not just by reading code: ran `omarchy-plugin/install.sh`
  to sync this branch into the actual dev-installed plugin
  (`~/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts`), which
  itself calls `config init` — confirmed the live
  `~/.config/omarchy-scripts/config.json` picked up `configVersion: 1`.
  Confirmed `show-config` is discovered with zero parse problems by the
  live installed runner, and running it
  (`bin/omarchy-scripts run show-config`) via that same live install
  prints output that matches the actual file on disk.

**Limitations / follow-ups:**

- No consumer reads `configVersion` yet (by design) — it will only
  matter once a real shape migration is needed.
