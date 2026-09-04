# Task: Example script that lists installed Omarchy plugins

Status: Ready
Type: feature

## Problem

We hit a real, confusing bug this session: the installed copy of this
very plugin at `~/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts`
was a stale plain-file copy (from `omarchy-plugin/install.sh`), not a
git clone, and there was no quick way to see that fact — it took manual
`ls`/`git remote -v` probing to figure out. There is no script that
simply answers "what plugins are installed, and how (git clone vs raw
copy), and are they enabled?"

## Scope

- Add `scripts/examples/list-installed-plugins.sh`.
- Enumerate `~/.config/omarchy/plugins/*` (respecting
  `XDG_CONFIG_HOME` like the rest of this project).
- For each plugin directory, report:
  - its id (directory name)
  - whether it's a git repository (`git -C <dir> rev-parse` succeeds) or
    a plain copy, and if a git repo, its remote URL and current commit
  - enabled/disabled state (check however Omarchy itself records this —
    inspect its plugin manifest/config convention; do not guess, look at
    a real installed plugin's manifest or Omarchy's own CLI/config to
    find the actual signal)
- No parameters required; an optional `format` choice
  (`choices=table,json`, default `table`) is reasonable.
- Header comments (`@script.*`, `@param`) must follow
  `docs/SCRIPT_SPEC.md` exactly, matching the existing example scripts'
  style.
- Add/extend a test in `tests/test_core.py` for metadata/list/validate
  visibility; live enumeration against a real
  `~/.config/omarchy/plugins/` is a manual verification step.
- Update `README.md`'s Example scripts list.

## What done looks like

- [ ] Script exists, parses via `list`/`validate` with no errors.
- [ ] Run against this real machine's plugin directory: correctly
      reports this plugin as (at time of writing) a raw copy, not a git
      clone, matching what we found manually this session.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, `make validate` pass.
- [ ] `README.md` documents the new script.

## Out of scope

- Any mutating action (enabling/disabling/removing) — this script is
  read-only reporting. See `example-install-omarchy-plugin.md` for the
  install/enable counterpart.

## Testing notes

- Run on this real machine and confirm the output matches what was
  found manually earlier this session (raw copy, not git clone, for
  `io.github.mdelgert.omarchy-scripts`).
- Run with zero plugins installed (or a temp `XDG_CONFIG_HOME`) and
  confirm a clear "none found" message instead of an error.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
