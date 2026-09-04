# Task: Example script that bumps a plugin manifest's version and tags it

Status: Ready
Type: feature

## Problem

Cutting a release of a plugin currently means manually editing its
manifest's version field and creating a matching git tag by hand, with
room for the two to drift out of sync (wrong tag name, forgotten
manifest edit, etc.). There is no script that does both atomically for
a given plugin directory.

## Scope

- Add `scripts/examples/bump-plugin-version.sh`.
- Parameters: `pluginPath` (`path`, runtime default to this checkout's
  own root), `newVersion` (`string`, required — a semver-ish string;
  validate loosely, e.g. `X.Y.Z`, and fail clearly on an obviously
  malformed value).
- Behavior: locate the manifest's version field (check this project's
  own `omarchy-plugin/` manifest for the actual field name/format used),
  update it to `newVersion`, commit that change (a small, clearly
  labeled commit), and create an annotated git tag `v<newVersion>`
  pointing at that commit. Fail clearly (without partial state) if the
  working tree already has uncommitted changes before starting, so this
  script's own commit doesn't accidentally bundle unrelated edits.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; the actual git commit/tag behavior is best tested against
  a disposable temp git repo fixture in the test itself (no live Omarchy
  dependency needed).
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run against a disposable temp git repo with a manifest: version
      field updates correctly, a commit and matching tag are created.
- [ ] Refuses to run against a dirty working tree, with a clear message
      naming what's uncommitted.
- [ ] An obviously malformed `newVersion` value is rejected clearly.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Pushing the resulting commit/tag anywhere — that remains a manual
  step (`git push --tags`) left to the user.
- Generating changelogs or release notes.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
