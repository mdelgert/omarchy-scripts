# Task: Configurable script directories via a settings file (set by CLI, not GUI)

Status: Done
Type: feature

## Problem

Script discovery is currently hardcoded to exactly two roots in
`discover()` (`src/omarchy_scripts/core.py`): the bundled `scripts/` dir
next to the engine, and a single workspace dir (`workspace_root()/scripts`,
default `~/.config/omarchy-scripts/scripts`, overridable only via the
`OMARCHY_SCRIPTS_HOME` env var). There's no way to add an arbitrary extra
directory — e.g. a team's shared scripts checked out from a separate git
repo, or a directory synced from another machine — without overriding the
one workspace root entirely.

## Design (agreed with user, keep it this simple — do not expand scope)

- A small JSON settings file, e.g. `~/.config/omarchy-scripts/config.json`
  (next to, not inside, `scripts/`), holding at minimum an ordered list of
  extra script directories: `{"scriptDirs": ["/path/one", "/path/two"]}`.
- The existing bundled root and the existing default workspace root
  (`~/.config/omarchy-scripts/scripts`) stay exactly as they are today and
  are always scanned — this file only adds *extra* roots on top, it does
  not replace or require reconfiguring the current default.
- **No settings UI.** The GUI (`Menu.qml`) stays minimal and read-only with
  respect to configuration — it never gains a settings screen, dialog, or
  form for editing `scriptDirs`. It only ever reads the resulting merged
  script list, exactly like it does today.
- Settings are read and written exclusively through the CLI, e.g.:
  - `omarchy-scripts config list-dirs`
  - `omarchy-scripts config add-dir <path>`
  - `omarchy-scripts config remove-dir <path>`
  A user (or a script, or a dotfiles-provisioning tool) runs these
  commands, or hand-edits the JSON file directly — both are first-class,
  the CLI subcommands are just a convenience wrapper around the same file.
- This is consistent with the rest of this project's philosophy: scripts
  and CLI commands are the primary interface, the GUI is a thin viewer/
  runner on top, not a place to reinvent settings forms.

## Scope

- Add `config_path()` alongside the existing `workspace_root()`/
  `state_root()` helpers, respecting the same override conventions
  (`OMARCHY_SCRIPTS_HOME` should probably relocate the config file too,
  for test isolation — match existing precedent).
- Extend `discover()`'s `locations` list to append each configured extra
  directory (tag its `source` clearly, e.g. `"external"`, distinct from
  `"bundled"`/`"workspace"` — GUI and `list`/`validate` output should be
  able to tell them apart).
- Define and document a deterministic id-collision precedence once there
  are more than two roots (simplest: scan order = bundled, workspace, then
  `scriptDirs` in the order listed — first one wins, matching the existing
  "first scanned wins, rest become problems" rule already in `discover()`).
- A configured directory that doesn't exist or isn't readable should show
  up in `problems` output (same treatment as an unreadable script file
  today), not be silently skipped.
- Add the `config` CLI subcommand(s) to `bin/omarchy-scripts`.
- Update `docs/SCRIPT_SPEC.md` and/or `docs/ARCHITECTURE.md` to document
  the config file's location, schema, and the "CLI configures, GUI only
  reads" contract explicitly, so a future contributor doesn't "helpfully"
  add a settings screen later.

## What done looks like

- [x] `omarchy-scripts config add-dir <path>` / `remove-dir` / `list-dirs`
      work and persist to the JSON config file.
- [x] Scripts under a configured extra directory show up in
      `omarchy-scripts list`/`validate` and in the live GUI after a reload,
      tagged with a distinct `source`.
- [x] A missing/unreadable configured directory is reported as a problem,
      not silently ignored.
- [x] Id collisions across 3+ roots follow one documented, tested
      precedence rule.
- [x] No new GUI surface for editing configuration was added.
- [x] Tests cover: adding/removing a dir, discovery picking up scripts from
      it, and the missing-directory problem case.
- [x] `make test`, `make lint-qml`, and `make validate` pass.
- [x] `docs/SCRIPT_SPEC.md`/`docs/ARCHITECTURE.md` document the config
      file schema and the CLI-configures/GUI-only-reads contract.

## Out of scope

- Any GUI settings/preferences screen — explicitly rejected by design, not
  just deferred.
- Per-directory enable/disable toggles, priority weighting beyond simple
  list order, or remote (non-local-filesystem) script sources.
- Migrating the existing `OMARCHY_SCRIPTS_HOME` env var override — it stays
  as-is for relocating the single default workspace root; this task is
  additive.

## Testing notes

Use `OMARCHY_SCRIPTS_HOME` (already the test-isolation mechanism) to point
at a throwaway config file location; don't touch the developer's real
`~/.config/omarchy-scripts/` while testing.

## Report

- Added `config.json` support in the Python engine, with `config_path()`,
  CLI `config list-dirs`/`add-dir`/`remove-dir`, and discovery of ordered
  extra script roots tagged as `source: "external"`.
- Kept precedence intentionally simple and documented it in both code and
  docs: bundled first, workspace second, then configured directories in
  `scriptDirs` order; first discovered id wins and later collisions become
  `problems`.
- Missing, unreadable, or non-directory configured roots now surface in
  `problems` instead of being skipped. Invalid `config.json` also surfaces as
  a config-file problem during discovery so `list`/`validate` stay diagnostic.
- Tests now cover CLI config persistence, external discovery, missing
  external directories, workspace-vs-external precedence, and configured
  external directory ordering.
- No GUI changes were made; the existing frontend remains a read-only
  consumer of the engine's merged script list.
