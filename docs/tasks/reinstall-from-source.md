# Task: Script that reinstalls the plugin from a source checkout

Status: Done
Type: feature

## Problem

Just hit this directly: PR #4 merged `configure-omarchy-scripts.sh` into
`main` in the source checkout, but the *installed* plugin at
`~/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts` is a plain
file copy made by `omarchy-plugin/install.sh` (dev-mode install), not a
git clone. Merging to `main` does nothing to that copy — the new script
was invisible in the running UI until `omarchy-plugin/install.sh` was
run again by hand, from a terminal, outside the plugin.

This is exactly the kind of one-off developer task this project's design
already treats as a first-class case: **if it's something you do to this
project, it should be a script the menu can run**, not a command only
reachable from a terminal. There's no principled reason "reinstall this
plugin from source" should be any different from "update a config value"
or "get hostname info" — install.sh is deterministic, idempotent, and
already the documented reinstall procedure (see its own header comment
and `README.md`'s "Quick start (development)" section).

## Scope

- Add a script (suggested id `reinstall-from-source`, category something
  like `Development`) that runs `omarchy-plugin/install.sh` from a given
  source checkout path and reports what happened.
  - One required `path`-type parameter for the source checkout directory
    (the working tree containing `omarchy-plugin/install.sh`), since
    `install.sh` derives its own source location from
    `${BASH_SOURCE[0]}` and there is no way to discover an arbitrary
    developer's checkout location automatically. Consider defaulting
    this to a configured value (see below) instead of requiring it
    every run.
  - Validate the given path actually contains
    `omarchy-plugin/install.sh` before running it, and fail with a clear
    error message (not a raw "no such file") if not.
  - Run the target `install.sh`, capture and print its output (which
    already reports "manifest validated" / "scripts validated" / "shell
    reloaded" or the appropriate failure), and propagate its exit code.
- Decide whether the source checkout path should be configurable via the
  existing generic config mechanism (e.g. a new key like
  `devSourcePath`, settable via `omarchy-scripts config set
  devSourcePath /home/you/Source/omarchy-scripts` or through
  `configure-omarchy-scripts.sh` if it makes sense to extend that
  script's parameters) so this script needs zero arguments on repeat
  runs. If added, reuse `_load_settings()`/`_write_settings()` — the
  same "one canonical settings mechanism" rule as every other
  config-touching task in this repo.
- Explicitly note in the script's own description/comments (and in the
  Report below) that running this script when installed *inside* the
  same directory it targets is a no-op self-copy with nothing new to
  copy in — the whole point of this script is to be run from the
  **already-installed, currently-stale** plugin instance, pointed *at*
  a separate up-to-date source checkout, not to be self-updating.
- Update `README.md`'s Example scripts list (or add a short
  "Development scripts" note) documenting this script and the
  self-copy caveat above.

## What done looks like

- [x] The new script exists, is discoverable via `list`/`validate`, and
      running it against this real source checkout (`/home/mdelgert/Source/omarchy-scripts`)
      reinstalls the plugin and the previously-missing script becomes
      visible without any manual terminal command.
- [x] A bad/nonexistent path produces a clear, specific error, not a
      raw shell failure.
- [x] Tests are added or updated where behavior changed.
- [x] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [x] `README.md` documents the new script and the self-copy caveat.

## Out of scope

- Any change to `omarchy-plugin/install.sh` itself — this task only
  wraps it as a callable script from within the UI.
- Automating *which* source path to use beyond an optional configured
  default — no auto-detection of "the" checkout; the user or an earlier
  configuration step supplies it.
- A parallel script for the `omarchy plugin add`/`update` (git-based)
  install path — that path is already a single documented command
  (`omarchy plugin update <id>`), not something needing a wrapper.

## Testing notes

- Run the new script pointed at the real source checkout and confirm
  `configure-omarchy-scripts` (or whatever is newest at the time) shows
  up afterward via `./bin/omarchy-scripts list` in the *installed*
  copy, mirroring the manual fix already performed once this session.
- Run it pointed at a path with no `omarchy-plugin/install.sh` and
  confirm the clear, specific error.
- If a configured default path is added, confirm the script still works
  when the parameter is omitted and a default is set, and still requires
  an explicit value (or fails clearly) when neither is present.

## Report

- Claimed on branch `task/reinstall-from-source`.

- Added bundled script `reinstall-from-source` in `scripts/examples/`. It
  accepts a `path` parameter, verifies the target contains
  `omarchy-plugin/install.sh`, then `exec`s that installer so its stdout,
  stderr, and exit code pass through unchanged.

- Decision: add an optional configured default source path. The script now
  falls back to `devSourcePath` in `config.json` when `path` is omitted, and
  the canonical settings mechanism normalizes that key through
  `_load_settings()` / `_write_settings()` via `set_config_value()`. I did
  **not** extend `configure-omarchy-scripts.sh`; the generic
  `omarchy-scripts config set devSourcePath ...` path was enough and kept
  this task scoped to the requested reinstall workflow.

- Updated `docs/SCRIPT_SPEC.md`, `docs/ARCHITECTURE.md`, and `README.md` to
  document `devSourcePath`, the new script, and the self-copy caveat: the
  useful case is a stale installed plugin copy pointing at a separate newer
  checkout, not targeting itself.

- Tests added in `tests/test_core.py` cover metadata/list/validate
  visibility, missing-path and missing-`install.sh` errors, exit-code
  propagation, and the configured-default fallback. Also added config tests
  for `devSourcePath` normalization/rejection.

- Verification:
  - `make test`
  - `make lint-qml`
  - `make validate`
  - `./bin/omarchy-scripts validate`
  - Live manual run from the installed plugin copy's
    `~/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts/bin/omarchy-scripts`
    against the branch checkout at
    `/home/mdelgert/Source/omarchy-scripts-reinstall-from-source`, confirming
    the previously-missing `scripts/examples/reinstall-from-source.sh` was
    present afterward in the installed plugin copy.
  - Live bad-path run from the installed copy, confirming the clear error
    `source checkout directory does not exist: ...`.
  - Live configured-default run from the installed copy after setting and then
    unsetting `devSourcePath`, confirming the parameter can be omitted on
    repeat runs.

- Limitation: because the task workflow requires a sibling git worktree for
  `task/reinstall-from-source`, the live source path used during verification
  was `/home/mdelgert/Source/omarchy-scripts-reinstall-from-source` rather
  than the original `/home/mdelgert/Source/omarchy-scripts` worktree.
