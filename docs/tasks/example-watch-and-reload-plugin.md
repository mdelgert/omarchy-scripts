# Task: Example script that watches a plugin source tree and hot-reloads it

Status: Ready
Type: feature

## Problem

Iterating on this plugin's own QML today means: edit a file, remember to
manually re-run `omarchy-plugin/install.sh`, wait for it to sync and
call `omarchy-shell shell rescanPlugins`. That manual loop is friction
during active development and is exactly the kind of repetitive
developer task this project's design says should be a script.
`reinstall-from-source.sh` (merged) does the one-shot version of this;
this task is the "keep doing it automatically while I edit" version.

## Scope

- Add `scripts/examples/watch-and-reload-plugin.sh`.
- Parameters: `sourcePath` (`path`, optionally falling back to a
  configured `devSourcePath` the same way `reinstall-from-source.sh`
  does), `intervalSeconds` (`integer`, `default=2`, min=1) as a
  polling-interval fallback if `inotifywait` isn't available.
- Behavior: watch `sourcePath` for changes (prefer `inotifywait` if
  present; fall back to polling mtimes at `intervalSeconds` if not —
  document this fallback clearly) and, on any change, run the same
  install-and-reload sequence `reinstall-from-source.sh` already
  implements (call that script, or its underlying `install.sh`, rather
  than duplicating the logic — reuse, don't reimplement).
- Since this script runs indefinitely (until interrupted), make sure its
  description/behavior make that clear to the user before they run it
  from the UI (e.g. explicit wording that it does not return until
  stopped) — check whether the engine's run UI already handles
  long-running/streaming scripts reasonably (see how `run` currently
  handles a script's stdout) and note any limitation found here in the
  Report rather than trying to fix the engine as part of this task.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; the actual watch-loop behavior is a manual verification
  step (it's inherently long-running/interactive).
- Update `README.md`'s Example scripts list, noting this is a
  long-running script (unlike every other current example).

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Editing a file under `sourcePath` while the script runs triggers a
      reinstall+reload within `intervalSeconds` (or immediately with
      `inotifywait`).
- [ ] Script description clearly states it runs until stopped
      (Ctrl-C/terminated), and does not silently hang with no
      indication of what's happening.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script and its long-running nature.

## Out of scope

- Any change to the core engine/UI to better support long-running
  scripts — if a real limitation is found (e.g. the run view assumes
  scripts finish quickly), document it as a follow-up task suggestion in
  the Report instead of fixing it here.

## Testing notes

- Run it, edit a file, and confirm reinstall+reload actually happens and
  is visible (e.g. via `list-installed-plugins.sh` or a timestamp check)
  within the expected interval.
- Confirm Ctrl-C / normal termination stops it cleanly.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
