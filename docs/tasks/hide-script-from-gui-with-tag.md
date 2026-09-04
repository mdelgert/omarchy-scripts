# Task: a reserved tag that hides a script from the GUI browse list

Status: Done
Type: feature

## Problem

There's no way to keep a script installed/runnable but keep it out of the
Scripts menu's browse list — e.g. a script meant only to be run by another
script, invoked directly via the CLI, or kept around half-finished without
cluttering the menu. `docs/SCRIPT_SPEC.md` already supports an optional,
purely descriptive `@script.tags` comma list
(`src/omarchy_scripts/core.py:179,605`, `Script.tags: list[str]`), but
nothing currently reads those tags to change what the GUI shows — the QML
menu's browse list is built by `ScriptModel.js`'s `rowsFor(scripts,
filterText)` (`omarchy-plugin/ScriptModel.js:114`), which currently includes
every script the engine returns, unconditionally.

## Scope

- Reserve one tag value, e.g. `hidden`, with meaning: "don't show this
  script in the Scripts menu's browsable list." Document it in
  `docs/SCRIPT_SPEC.md` next to the existing `@script.tags` description as
  a recognized value with special meaning, alongside the existing
  free-form tags (e.g. `# @script.tags network,hidden`).
- No engine (`core.py`)/CLI contract change needed: `tags` is already
  parsed and returned as-is in every script's JSON
  (`Script.to_dict()`/`schemaVersion` unaffected, purely additive
  interpretation of an existing field) — per `AGENTS.md`'s "keep the
  Python engine frontend-neutral," this is a **frontend-only** filtering
  decision, not something `discover()`/`list` should drop or special-case
  server-side. The CLI (`list`, `info`, etc.) keeps returning hidden
  scripts exactly as before — hiding only applies to the QML browse
  list, not to scripting/automation use of the CLI.
- In `omarchy-plugin/ScriptModel.js`, filter scripts carrying the `hidden`
  tag out of `rowsFor()`'s output (alongside or inside the existing
  `matchesFilter` filtering step), so they never appear in the browse
  list or its type-to-filter search.
- Decide and document: should a hidden script still be reachable through
  the detail view if a caller already knows its id (e.g.
  `omarchy-shell shell toggle ... '{"scriptId": "..."}'` or a future deep
  link), or should it be excluded everywhere the QML plugin surfaces
  scripts? Default assumption for this task: hidden only affects the
  *browse list*; if something else already knows the script's id and
  opens it directly, that still works — consistent with "hidden from
  casual browsing," not "fully inaccessible."

## What done looks like

- [x] A script with `# @script.tags hidden` (alone or combined with other
      tags, e.g. `network,hidden`) does not appear in the Scripts menu's
      browse list, verified live in an Omarchy/Hyprland session.
- [x] The same script still appears in `omarchy-scripts list` CLI output
      and can still be run via `omarchy-scripts run <id>` — hiding is a
      GUI browse-list concern only, not a discovery/execution one.
- [x] Un-hidden scripts (no `hidden` tag) are unaffected — no regression
      to the existing browse list, filter, or category grouping.
- [x] `docs/SCRIPT_SPEC.md` documents the reserved `hidden` tag value and
      what it does (and does not) affect.
- [x] Tests added/updated in `tests/test_core.py` if any engine-level
      behavior changed — none needed: this is pure JS-side filtering in
      `ScriptModel.js`, no engine/CLI contract changed, so no Python test
      changes apply. Verified instead via a standalone `node` sanity
      check of the JS logic plus live testing (below).
- [x] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.

## Out of scope

- Any new dedicated metadata key (e.g. `@script.hidden true`) — this task
  specifically reuses the existing `tags` mechanism with a reserved
  value, not a new field. If a reviewer strongly prefers a dedicated
  boolean field instead, raise that as a design question before
  implementing, don't silently switch approaches.
- A GUI toggle/checkbox to hide/unhide a script from within the menu
  itself (e.g. on the detail view's action row) — this task is only
  about the tag itself and the browse-list filter honoring it. Authoring
  the tag by hand (or via `edit`) is enough for v1.
- Hiding scripts from `omarchy-scripts list`/other CLI output — explicitly
  out of scope per the frontend-neutral scoping above.

## Testing notes

- Add (or temporarily mark) a workspace script with `@script.tags hidden`
  and confirm it's absent from the browse list and its type-to-filter
  search, live in a real Omarchy/Hyprland session.
- Confirm `omarchy-scripts list` still includes it and `omarchy-scripts
  run <id>` still runs it.
- Confirm a script with `tags` that include `hidden` alongside other tags
  (e.g. `network,hidden`) is still hidden — the check should look for the
  tag by value within the list, not require it to be the only tag.

## Report

**Changed:**
- `docs/SCRIPT_SPEC.md`: documented the reserved `hidden` tag value next
  to the existing `tags` field description, explicitly noting it's a
  QML-only presentation decision, not an engine/CLI one.
- `omarchy-plugin/ScriptModel.js`: added `isHidden(script)` (checks
  whether `"hidden"` is present in the script's `tags` array) and applied
  it in `rowsFor()`'s existing filter step, alongside `matchesFilter()`,
  so a hidden script is excluded before rows/category headers are built —
  never rendered in the browse list or matched by type-to-filter search
  (including searching for the literal word "hidden" itself).
- No changes to `core.py`/the CLI/the JSON contract: `tags` was already
  parsed and returned as-is; this task only adds a frontend
  interpretation of an existing field, per `AGENTS.md`'s frontend-neutral
  engine rule.

**Verified:**
- A standalone `node` run of the (lightly stubbed, `.pragma library`
  stripped) `ScriptModel.js` confirmed `rowsFor()` correctly excludes
  scripts tagged `hidden` (including one with `["network", "hidden"]`,
  proving it's a substring-of-list check, not "must be the only tag")
  while leaving untagged/other-tagged scripts untouched.
- Live in a real Hyprland/quickshell session: added a temporary workspace
  script (`hidden-test-script.sh`, `@script.tags hidden`), installed,
  confirmed via CLI that `omarchy-scripts list` still includes it and
  `omarchy-scripts run hidden-test-script` still runs it successfully.
  In the QML menu, filtering the browse list by the literal text
  "hidden" returned zero rows — confirming the script is excluded even
  when a search term would otherwise match its own tag text. Removed the
  temporary script and reinstalled/restarted from `main`'s build
  afterward so the live session was left in its normal state.
- `make test` (49/49, no new/changed Python tests — none applicable),
  `make lint-qml` (same 4 documented pre-existing warning categories, no
  new one), `make validate` (0 problems, 9 scripts).

**Limitations / follow-ups:**
- No GUI affordance to toggle `hidden` from within the menu itself was
  added (out of scope per the task) — authoring/editing the tag by hand
  (or via the existing `edit` action, which opens the script file) is the
  only way to set it today.
- `omarchy-plugin/ScriptModel.js`'s pre-existing `groupByCategory()`
  helper is unused elsewhere in the codebase and was left untouched — it
  isn't part of the browse-list rendering path this task changes.
