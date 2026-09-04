# Task: Example script that lints and formats an arbitrary plugin directory

Status: Ready
Type: feature

## Problem

This repo already has `make lint-qml` for its own QML, and Bash scripts
in `scripts/examples/` are presumably expected to be shellcheck-clean,
but there is no single script a developer can point at *any* plugin
directory (this one, `omarchy-recipes`, or a new one) to get a quick
pass/fail lint report across both QML and shell files, without knowing
each project's own Makefile targets.

## Scope

- Add `scripts/examples/lint-and-format.sh`.
- Parameters: `pluginPath` (`path`, runtime default to this checkout's
  own root, following the same runtime-fallback pattern as other
  scripts in this project).
- Behavior:
  - Run `qmllint` (or whatever `make lint-qml` in this repo actually
    invokes — reuse that exact mechanism/exclude list rather than
    reinventing it) against `.qml` files under `pluginPath`.
  - Run `shellcheck` against `.sh` files under `pluginPath`, if
    `shellcheck` is available; report a clear, specific message if it
    isn't installed rather than a raw "command not found".
  - Summarize pass/fail counts per tool at the end; propagate a
    non-zero exit code if anything failed.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; actual linting is a manual verification step (depends on
  `qmllint`/`shellcheck` availability, same caveat as `make lint-qml`
  already documents).
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run against this repo's own root: reports the same benign warning
      categories `make lint-qml` already reports, and shellcheck results
      for `scripts/examples/*.sh`.
- [ ] Missing `shellcheck`/`qmllint` produces a clear, specific message,
      not a raw tool-not-found error.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Actually fixing/auto-formatting any lint findings — this script only
  reports.
- Any new linting rules beyond what `make lint-qml` and `shellcheck`'s
  defaults already check.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
