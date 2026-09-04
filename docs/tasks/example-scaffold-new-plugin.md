# Task: Example script that scaffolds a new Omarchy plugin skeleton

Status: Ready
Type: feature

## Problem

Starting a brand-new Omarchy plugin (this repo and `omarchy-recipes` are
the only two examples) currently means manually copying files from an
existing plugin and editing a manifest by hand. There is no script that
generates a minimal, valid skeleton (manifest, QML entry point, `bin/`
wrapper) for a new plugin id/title, the same way scaffolding tools exist
for other frameworks.

## Scope

- Add `scripts/examples/scaffold-new-plugin.sh`.
- Parameters: `pluginId` (`string`, required, must match the reverse-DNS
  style used by this project, e.g. `io.github.<you>.<name>`),
  `title` (`string`, required), `destPath` (`path`, runtime default
  `$HOME/Source/<pluginId-last-segment>` following the
  `${SCRIPT_ARG_...:-default}` runtime-expansion pattern, not a metadata
  default).
- Behavior: create `destPath` with a minimal valid structure — look at
  this repo's own `omarchy-plugin/` directory (manifest, QML entry
  point) as the template to copy and parameterize (substitute the id and
  title into the manifest). Keep it minimal: just enough to pass
  `omarchy-plugin-validate` with a trivial placeholder shell, not a full
  copy of this project's engine.
- Print next steps (e.g. "cd into `<destPath>` and run
  `omarchy-plugin/install.sh`" or equivalent) after generating.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; generating and validating a real skeleton is a manual
  verification step (or an automated test if `omarchy-plugin-validate`
  is available in the test environment — check how existing tests
  handle that dependency, if at all).
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Running it produces a directory that passes
      `omarchy-plugin-validate` (when that tool is available) with no
      errors, for a fresh id/title.
- [ ] Refuses to overwrite an existing non-empty `destPath` with a clear
      error instead of silently clobbering it.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Generating a full engine/CLI like this project's — the skeleton is
  intentionally minimal (manifest + trivial QML), not a second
  `omarchy-scripts`.
- Git-initializing or pushing the new directory anywhere — that's a
  separate, manual step for the user.

## Testing notes

- Generate a skeleton, run `omarchy-plugin-validate` against it (if
  available on this machine) and confirm it passes.
- Run twice against the same `destPath` and confirm the second run
  refuses cleanly rather than overwriting.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
