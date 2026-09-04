# Task: Example script that runs another plugin repo's test suite

Status: Ready
Type: feature

## Problem

Both `omarchy-scripts` and `omarchy-recipes` (and any future plugin
repo) have their own `make test`, but there is no single script that
works across all of them without remembering each repo's specific
command — useful for a developer juggling several plugin checkouts who
wants one consistent "run this repo's tests" action available from the
menu itself.

## Scope

- Add `scripts/examples/run-plugin-tests.sh`.
- Parameters: `repoPath` (`path`, runtime default to this checkout's own
  root).
- Behavior: `cd` into `repoPath` and run `make test` if a `Makefile`
  with a `test` target exists there; otherwise fail with a clear,
  specific message naming what was tried and why it didn't run (do not
  silently no-op). Keep detection simple — `make test` is already the
  documented convention in this project and `omarchy-recipes`; do not
  try to auto-detect pytest/npm/etc. beyond that unless it's genuinely
  trivial.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; running it against a real second repo
  (`omarchy-recipes`) is a manual verification step.
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run with the default path: runs and reports this repo's own
      `make test` results correctly.
- [ ] Run against `omarchy-recipes`'s checkout path (if present on this
      machine) and reports its `make test` results correctly.
- [ ] Run against a directory with no `Makefile`/`test` target and get
      a clear, specific failure message.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Auto-detecting non-`make`-based test runners.
- Aggregating results across multiple repos in one run — this script
  targets one `repoPath` per run.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
