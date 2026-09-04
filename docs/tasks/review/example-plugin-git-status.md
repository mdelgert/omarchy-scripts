# Task: Example script that shows git status across several plugin checkouts

Status: Ready
Type: feature

## Problem

A developer working across multiple plugin source checkouts (this one,
`omarchy-recipes`, others scaffolded later) has to `cd` into each one
individually and run `git status`/`git branch` to remember what's
uncommitted or which branch each is on. There is no single script that
reports this across a configured list of checkouts at once.

## Scope

- Add `scripts/examples/plugin-git-status.sh`.
- Parameters: `repoPaths` (`string`, comma-separated list of paths,
  runtime default falling back to a configured value — reuse the same
  generic config mechanism already used for `scriptDirs`/`devSourcePath`,
  e.g. a new key like `devRepoPaths`, via `_load_settings()`/
  `_write_settings()` — do not invent a third settings abstraction).
- Behavior: for each path, print its current branch, ahead/behind vs.
  upstream if available, and a summary of uncommitted changes
  (`git status --short` count of modified/untracked files). Skip
  non-existent or non-git paths with a clear per-entry warning rather
  than aborting the whole run.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility, plus a test exercising the comma-separated parsing logic
  against fixture directories (can use plain temp git repos in the test,
  no live Omarchy dependency needed here).
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run against this repo and `omarchy-recipes` (if present) reports
      accurate branch/status for both.
- [ ] A bad/nonexistent path in the list produces a clear per-entry
      warning, not a script abort.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Any mutating git action (fetch, pull, commit) — read-only reporting
  only.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
