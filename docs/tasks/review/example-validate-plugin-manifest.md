# Task: Example script that validates any Omarchy plugin's manifest

Status: Ready
Type: feature

## Problem

`omarchy-plugin-validate` already exists as a system tool and this
project's own `install.sh`/`make validate` already call it against
*this* plugin. There is no quick script to point that same validation
at an arbitrary plugin directory — useful when working across multiple
plugin repos (this one, `omarchy-recipes`, or a brand-new one scaffolded
via `example-scaffold-new-plugin.md`) without remembering the exact
underlying command each time.

## Scope

- Add `scripts/examples/validate-plugin-manifest.sh`.
- Parameters: `pluginPath` (`path`, no metadata default — runtime
  default to the currently-installed copy of *this* plugin, e.g.
  `${SCRIPT_ARG_PLUGINPATH:-$HOME/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts}`,
  matching the `${SCRIPT_ARG_PATH:-$HOME}` runtime-fallback pattern).
- Behavior: run `omarchy-plugin-validate <pluginPath>` if that tool is
  present; fail with a clear, specific message if it isn't installed
  (rather than a raw "command not found"). Propagate its exit code and
  print its output as-is.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; actual validation against a real plugin directory is a
  manual verification step (depends on `omarchy-plugin-validate` being
  installed, which is an Omarchy-session dependency like others in this
  project).
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run with the default path on this real machine: matches running
      `omarchy-plugin-validate` by hand against the same path.
- [ ] Run against a deliberately broken manifest (e.g. a scaffolded
      plugin with a missing required field) and confirm the failure is
      reported clearly.
- [ ] Missing `omarchy-plugin-validate` produces a clear, specific
      error, not a raw "command not found".
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Reimplementing manifest validation logic — this is a thin wrapper
  around the existing system tool only.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
