# Task: Generic `config set`/`get` for scripting, instead of one-off subcommands per setting

Status: Done
Type: feature
Claimed by: Copilot (@mdelgert_church) on 2026-09-03T19:35:10.729-07:00

## Problem

Two independent settings now live in the same `config.json`
(`scriptDirs`, added by `configurable-script-directories.md`, and `keys`,
added by `configurable-menu-keybindings.md`), and each grew its own
bespoke CLI surface:

- `scriptDirs` got `omarchy-scripts config add-dir/remove-dir/list-dirs`.
- `keys` got **no CLI mutator at all** — the task's design explicitly said
  "edit the JSON (by hand, or via a future `config set-key` CLI
  convenience... start with just the file)", and that CLI convenience was
  never added, so remapping a key today means hand-editing
  `~/.config/omarchy-scripts/config.json` directly.

This project's whole philosophy (see both tasks above, and
`docs/GITHUB_TOKEN_SETUP.md`'s "CLI configures, GUI reads" framing) is that
**scripts, not GUIs, set configuration** — a provisioning script, a
dotfiles repo, or an agent following `skills/task-workflow/SKILL.md` should
be able to set any config value non-interactively. Right now that's only
true for one of the two settings that exist, and every *future* setting
would otherwise need its own bespoke `add-x`/`remove-x`/`set-x` subcommand
pair, which doesn't scale.

## What "done" looks like

Add one generic pair of subcommands that works for any key in
`config.json`, generalizing what `add-dir`/`remove-dir` do today for
`scriptDirs` specifically:

```bash
omarchy-scripts config get <dotted.path>
omarchy-scripts config set <dotted.path> <value>
omarchy-scripts config unset <dotted.path>
```

Examples, using the two settings that already exist:

```bash
omarchy-scripts config set keys.moveDown j
omarchy-scripts config get keys.moveDown        # -> "j"
omarchy-scripts config unset keys.moveDown       # back to built-in default
omarchy-scripts config get scriptDirs            # -> ["/path/one", "/path/two"]
```

Design constraints:

- `set` should validate the value against whatever that key already
  validates against when the engine loads it (e.g. `keys.*` goes through
  `parse_key_spec()`, a `scriptDirs` entry gets the same path-normalization
  `add_script_dir()` already does) — don't let `config set` write a value
  that `list`/discovery would then report as a problem. Reject with a clear
  error instead.
- `value` arrives as a string from argv; parse it as JSON first
  (`json.loads`) and fall back to the raw string if that fails, so
  `config set scriptDirs '["/a","/b"]'` and `config set keys.moveDown j`
  both work without the caller needing to know which type each key expects.
- This is additive: **do not remove** `add-dir`/`remove-dir`/`list-dirs`.
  They're a nicer, path-specific ergonomic wrapper for the one setting that
  benefits from it (append/remove-from-a-list semantics); keep them as a
  convenience layer on top of the same underlying generic read/write
  helpers, not a competing implementation.
- No GUI surface for this, same rule as both prior config tasks — this is
  CLI/scripting-only by design, not an oversight to fix later.

## Scope

- A small dotted-path get/set/unset helper in `core.py` operating on the
  same `_load_settings()`/`_write_settings()` pair both existing config
  features already use — don't invent a third settings-file abstraction.
- Per-key validation hooks for at least the two settings that exist today
  (`keys.*` via `parse_key_spec`, `scriptDirs` via the existing path
  normalization) so `set` can reject bad input with a useful error, not
  just accept anything and let it silently misbehave later.
- Wire `config get`/`set`/`unset` into `bin/omarchy-scripts` alongside the
  existing `config` subcommands.
- Document the generic get/set/unset commands in `docs/SCRIPT_SPEC.md`
  next to the existing `keys`/`scriptDirs` schema documentation, and note
  that `add-dir`/`remove-dir` are a convenience wrapper over the same
  mechanism, not a separate one.

## What done looks like

- [x] `config set keys.moveDown j` persists and is picked up by the menu
      after a reload/restart, exactly like hand-editing the file today.
- [x] `config set` on a `keys.*` path rejects an invalid key spec with a
      clear error and does not write the bad value to disk.
- [x] `config get`/`unset` work for both `keys.*` and `scriptDirs`.
- [x] `add-dir`/`remove-dir`/`list-dirs` still work unchanged and are
      documented as a convenience layer over the generic mechanism.
- [x] Tests cover: set + get round-trip for both a `keys.*` path and
      `scriptDirs`, unset reverting to default, and a rejected invalid
      value.
- [x] `make test`, `make lint-qml`, and `make validate` pass.
- [x] `docs/SCRIPT_SPEC.md` documents the generic commands.

## Out of scope

- A GUI settings screen — still explicitly rejected, same as both prior
  config tasks.
- Any new top-level settings beyond `keys`/`scriptDirs` — this task is only
  about the access mechanism, not adding new configurable behavior.
- Validating arbitrary/unknown dotted paths beyond what the two existing
  settings already need — don't build a general schema system for this,
  keep the per-key validation hooks minimal and explicit.

## Testing notes

Use `OMARCHY_SCRIPTS_HOME` (already the test-isolation mechanism) to point
at a throwaway config location, matching how the two prior config tasks
tested.

## Report

- Added generic engine helpers in `core.py` for dotted-path
  `get_config_value()`, `set_config_value()`, and `unset_config_value()`
  backed by the existing `_load_settings()` / `_write_settings()` pair.
  `scriptDirs` now validates and normalizes through that shared path, and
  `add-dir` / `remove-dir` were reduced to convenience wrappers over the
  same generic setter instead of keeping separate write logic.
- Added CLI subcommands `omarchy-scripts config get/set/unset` in
  `cli.py`. `config set` parses argv values as JSON first and falls back to
  the raw string, so both scalar keybindings and JSON arrays work from
  shell scripts without callers needing per-setting special cases.
- Validation remains explicit and minimal, matching current settings:
  `keys.*` values must be valid key specs and `scriptDirs` must be a JSON
  array of strings. Unknown future keys still round-trip structurally
  without adding a larger schema system.
- Extended tests to cover generic get/set/unset, JSON parsing for
  `scriptDirs`, default restoration after unsetting `keys.moveDown`, and
  rejected invalid key specs that do not write to disk.
- Updated `docs/ARCHITECTURE.md` and `docs/SCRIPT_SPEC.md` to document the
  new CLI surface and clarify that `add-dir` / `remove-dir` are wrappers
  over the shared config mechanism.
- Verified with `make test`, `make lint-qml`, `make validate`, direct
  `./bin/omarchy-scripts validate`, and manual CLI exercises for generic
  keys, generic scalar values, and the existing directory-management
  commands under an isolated `OMARCHY_SCRIPTS_HOME`.
