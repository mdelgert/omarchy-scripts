# Task: add a `configVersion` value to config.json, and a script that reads it

Status: Ready
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

Fill in when finished: what changed, decisions made, limitations, and
useful follow-ups. Set Status to Done after merge, then move the
completed file to `docs/tasks/done/`.
