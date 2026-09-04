# Task: Example script that clones a git repository (self-referential default)

Status: Ready
Type: feature

## Problem

None of the current example scripts (`greet-user.sh`, `hostname-info.sh`,
`largest-directories.sh`, `check-website-status.sh`,
`configure-omarchy-scripts.sh`, `reinstall-from-source.sh`) demonstrate
one of the most common everyday scripts a developer actually runs:
cloning a git repository. It's also a good, simple demonstration of a
**static** `@param default=` value (as opposed to the dynamic
current-value confusion flagged in
`docs/tasks/materialize-default-config-file.md`) — a hardcoded default
URL is exactly what static metadata defaults are for, since a repo URL
genuinely doesn't change at runtime the way "current key binding" does.

## Scope

- Add `scripts/examples/clone-repository.sh`.
- Parameters:
  - `repoUrl` (`string`, `default=https://github.com/mdelgert/omarchy-scripts.git`,
    required) — defaults to *this very repository* as a friendly,
    always-valid, self-referential example a user can run immediately
    with zero required input.
  - `destPath` (`path`, no metadata default — same reason `path` has no
    metadata default in `largest-directories.sh`: `$HOME` must be
    expanded at run time, not stored as a comment literal). Fall back to
    `${SCRIPT_ARG_DESTPATH:-$HOME/Source}` (or similar) at runtime,
    matching the existing `${SCRIPT_ARG_PATH:-$HOME}` pattern.
  - Optional `branch` (`string`, blank = default branch) if that seems
    worth the small extra complexity; otherwise document as a possible
    follow-up instead of adding it.
- Behavior: run `git clone [--branch <branch>] <repoUrl> <destPath>/<repo-name-derived-from-url>`
  (or clone directly into `destPath` if that's simpler and still
  sensible — pick one and document the choice). Print the resulting
  path on success.
- Handle the already-cloned case gracefully (e.g. destination already
  exists and is a non-empty directory) with a clear message rather than
  a raw `git` error dump — but do not attempt to implement update/pull
  semantics; a second run against an existing clone can simply report
  "already exists at `<path>`" and exit non-zero, or perform a `git pull`
  if that is trivial and safe. Pick the simpler option and document it.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly, matching the style of the other example
  scripts.
- Add/extend a test in `tests/test_core.py` confirming the new script
  parses correctly and appears in `list`/`validate` output.
- Update `README.md`'s Example scripts list with a one-line description.

## What done looks like

- [ ] `scripts/examples/clone-repository.sh` exists, is executable, and
      parses via `./bin/omarchy-scripts list` / `validate` with no
      errors.
- [ ] Running it with all defaults (only supplying nothing beyond the
      static default `repoUrl`) actually clones this repository
      somewhere under the runtime-resolved `destPath` default.
- [ ] Running it against a destination that's already a non-empty
      directory produces a clear message instead of a confusing raw
      `git` error.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.
- [ ] `README.md`'s Example scripts section documents the new script.

## Out of scope

- Any authentication handling for private repositories (SSH keys,
  tokens) — this example is for public/anonymous clone only.
- Update/pull/sync behavior for an existing clone beyond the simple
  graceful-message (or trivial `git pull`) handling described above.

## Testing notes

- Run with all defaults in an isolated temp `HOME`/`destPath` override
  and confirm the real clone succeeds and lands where documented.
- Run a second time against the same destination and confirm the
  graceful-already-exists behavior, not a raw error.
- Run with an invalid/unreachable `repoUrl` and confirm the underlying
  `git clone` failure is surfaced clearly (exit code non-zero, readable
  stderr).

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
