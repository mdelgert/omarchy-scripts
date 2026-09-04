# Task: Example script that packages a plugin for distribution

Status: Ready
Type: feature

## Problem

`README.md`'s Install section documents `omarchy plugin add` (git clone)
as the normal install path, but there is no equivalent for distributing
a plugin *outside* git — e.g. a clean `.tar.gz` a user downloads and
extracts manually, which `omarchy-plugin/install.sh`'s own comments
already acknowledge as a supported (if secondary) install shape ("one
copied in by `install.sh`" is referenced in this repo's own README
Remove section). There is no script that produces such a clean archive.

## Scope

- Add `scripts/examples/package-plugin-release.sh`.
- Parameters: `pluginPath` (`path`, runtime default to this checkout's
  own root), `outputPath` (`path`, runtime default to
  `$HOME/<pluginId>-<version>.tar.gz` — read the version the same way
  `example-bump-plugin-version.md` does, from the manifest).
- Behavior: produce a `.tar.gz` of `pluginPath` using the exact same
  exclude list `omarchy-plugin/install.sh` already uses (`.git/`,
  `.github/`, `.qml-imports/`, `__pycache__/`, `*.pyc`) so the packaged
  archive matches what a real install would contain — reuse that list
  literally rather than re-deriving it, to avoid the two drifting apart
  over time.
- After creating the archive, run `omarchy-plugin-validate` against a
  fresh extraction of it (in a temp directory) if that tool is
  available, to confirm the packaged result is actually valid before
  reporting success.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; actual packaging against this real repo is a manual
  verification step.
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run against this repo: produces a `.tar.gz` that, when extracted,
      passes `omarchy-plugin-validate` (when that tool is available).
- [ ] The archive excludes exactly what `omarchy-plugin/install.sh`
      excludes — no `.git/`, no `__pycache__/`, etc.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Uploading/publishing the archive anywhere — this script only produces
  a local file.
- Any signing/checksumming of the release artifact.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
