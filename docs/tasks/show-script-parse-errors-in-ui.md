# Task: show script parse-error details in the UI, not just "see terminal"

Status: Ready
Type: feature

## Problem

When one or more scripts fail to parse, the browse view only shows a
count: `N script(s) failed to parse — see terminal / \`omarchy-scripts
validate\``. To see *which* script and *why*, the user has to leave the UI
and open a terminal to run `omarchy-scripts validate`. That's inconvenient
for a desktop-menu tool whose whole point is not needing a terminal.

The data already exists: `ScriptEngine.problems` (backed by
`core.discover()`'s second return value) is a list of
`{"path": <str>, "error": <str>}` objects (see `core.py:638-680`,
`Menu.qml:514`). Nothing needs to be computed — it just isn't surfaced.

## Scope

- In `Menu.qml`, replace (or extend) the current one-line problems summary
  with the actual per-problem detail: for each entry in
  `scriptEngine.problems`, show its `path` and `error` (e.g.
  `<path>: <error>`), not just a count.
- Keep it simple: inline text in the existing browse view is enough — no
  new dialog, popup, or view mode is required. Wrap/elide long paths and
  error text as the existing `problemsLine`/`settingsProblemsLine` Text
  elements already do.
- If the full list would be too long for the panel, cap the number of
  inline entries shown (e.g. first 3-5) and append a
  "and N more — see \`omarchy-scripts validate\`" fallback for the rest,
  so the terminal/CLI path still exists as a fallback, just isn't the only
  path.
- No `core.py`/`cli.py` changes are expected — `problems` already carries
  everything needed. If you find the `error` string itself is not useful
  enough (e.g. missing file/line context) for some parse-failure case,
  that's a separate, out-of-scope problem — flag it in the Report rather
  than expanding scope to fix message quality in `core.py`.

## What done looks like

- [ ] Deliberately breaking a script's metadata (e.g. malformed `@param`
      line or duplicate `@script.id`) and opening the menu shows the
      specific path and error text in the UI, without needing a terminal.
- [ ] The existing count-only fallback (or `omarchy-scripts validate`) is
      still available/mentioned when there are more problems than fit
      inline.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [ ] Documentation is updated if this changes any documented UI/contract
      (check `docs/ARCHITECTURE.md`/`docs/SCRIPT_SPEC.md` for existing
      mentions of the problems summary).

## Out of scope

- Changing what `core.discover()` puts in a problem's `error` string, or
  adding line numbers/richer diagnostics to parse errors.
- Any dedicated "problems" view, dialog, tooltip, or keyboard-navigable
  list — plain inline text is sufficient for v1.
- Auto-opening a terminal or editor at the failing file (that's a
  reasonable future follow-up, not this task).

## Testing notes

- Manually create/rename a script under `scripts/examples/` or a
  `scriptDirs` folder with a broken `@param` line (or a duplicate
  `@script.id` colliding with an existing script) and confirm the browse
  view shows its path + error text directly, verified live via
  `omarchy-restart-shell` / `omarchy-shell shell toggle` + a screenshot,
  not just by reading QML.
- Confirm `scriptEngine.settingsProblems` (the separate settings-file
  problem line just below) is unaffected.

## Report

Fill in when finished: what changed, decisions made, limitations, and
useful follow-ups. Set Status to Done after merge, then move the
completed file to `docs/tasks/done/`.
