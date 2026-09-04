# Task: Example script that diffs an installed plugin against its source checkout

Status: Ready
Type: feature

## Problem

The exact bug hit this session (PR #4 merged to `main`, but the
installed copy at `~/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts`
didn't have the new script) was only caught by accident, because the
user happened to look for the script and not find it. There is no
script that proactively answers "is my installed plugin copy actually
in sync with its source checkout?" — which is exactly the check that
would have caught the staleness immediately, before confusion set in.

## Scope

- Add `scripts/examples/diff-installed-vs-source.sh`.
- Parameters: `pluginId` (`string`, `default=io.github.mdelgert.omarchy-scripts`)
  and `sourcePath` (`path`, no metadata default — resolve a sensible
  runtime default the same way `reinstall-from-source.sh` does, e.g. an
  optional configured `devSourcePath`, falling back to requiring the
  value).
- Behavior: run something equivalent to
  `rsync -a --delete --dry-run <same excludes as omarchy-plugin/install.sh> <sourcePath>/ <installed-dir>/`
  (or a plain recursive diff) and report exactly what would change —
  files that would be added, removed, or modified — without changing
  anything. Exit non-zero if there are differences, zero if already in
  sync, so it's easy to use as a quick health check.
- Reuse the same exclude list `omarchy-plugin/install.sh` uses
  (`.git/`, `.github/`, `.qml-imports/`, `__pycache__/`, `*.pyc`) so the
  comparison is apples-to-apples with what a real reinstall would do.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; live diffing is a manual verification step.
- Update `README.md`'s Example scripts list, cross-referencing
  `reinstall-from-source.sh` as the fix for whatever this script finds.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run against this real machine right after a merge with no
      reinstall: correctly reports the installed copy is out of sync
      (matching what was found manually this session).
- [ ] Run immediately after `reinstall-from-source.sh`: correctly
      reports back in sync, exit code 0.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Actually performing the sync — that's `reinstall-from-source.sh`'s
  job; this script is read-only/reporting only.

## Testing notes

- Deliberately go out of sync (touch a file in the source checkout
  without reinstalling) and confirm the script reports it.
- Run `reinstall-from-source.sh` then re-run this script and confirm it
  now reports in sync.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
