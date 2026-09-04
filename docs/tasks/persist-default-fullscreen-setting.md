# Task: persist a default "open fullscreen" setting for the menu

Status: Ready
Type: feature

## Problem

Today `fullscreen` is only ever set per-invocation, from the keybind's
JSON payload (`Menu.qml:50`: `root.fullscreen = !!payload.fullscreen`) —
e.g. `SUPER + R` binds to `{"fullscreen":true}` per `README.md`. There's
no way to make "always open fullscreen" (or "always open small") the
*default*, short of rebinding every keybind's payload by hand. Some users
want the menu full-size every time; others don't; this should be a small,
persisted config setting, not something that requires editing keybinds.

Note on scope: this is deliberately narrow. The *actual terminal window*
a script runs in (`omarchy-launch-floating-terminal-with-presentation`)
and the logo it shows (`omarchy-show-logo`, which just `cat`s a static
`$OMARCHY_PATH/logo.txt`) are both owned by Omarchy itself, not this
repo, and neither currently has any size/scale knob to control — making
those configurable would mean patching Omarchy, which is out of scope
here. This task only covers this plugin's own browse/detail *menu panel*
fullscreen state, which is the one thing already fully within
`omarchy-scripts`' control.

## Scope

- Add a `fullscreen` boolean to `config.json`'s materialized defaults
  (`core.py`'s `materialize_default_config()`, alongside `keys`/
  `scriptDirs`), defaulting to `false` — same "only fill in if missing,
  never overwrite" contract already used there.
- In `Menu.qml`'s `open(payloadJson)`, use the payload's `fullscreen` when
  the caller explicitly passed one, but fall back to the configured
  default when it's absent (today `!!payload.fullscreen` collapses
  "not present" and "explicitly false" to the same thing — that
  distinction needs to be preserved: `payload.fullscreen !== undefined`
  should win over the config default either way).
- Expose it as a settable field in `configure-omarchy-scripts.sh`
  (a `boolean` `@param`, per `docs/SCRIPT_SPEC.md`'s existing `boolean`
  type), alongside the existing key-binding fields.
- Update `tests/test_core.py` for the new `materialize_default_config()`
  key, and any QML test/fixture asserting on `config.json`'s shape.

## What done looks like

- [ ] Setting the config default to `true` (via
      `configure-omarchy-scripts.sh` or `omarchy-scripts config set
      fullscreen true`) makes the menu open fullscreen on a plain
      `omarchy-shell shell toggle io.github.mdelgert.omarchy-scripts '{}'`
      (no payload override), verified live via `omarchy-restart-shell`.
- [ ] An explicit payload (`{"fullscreen": false}`) still overrides the
      configured default in either direction.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [ ] `docs/SCRIPT_SPEC.md`/`docs/ARCHITECTURE.md`/`README.md` updated if
      they document `config.json`'s shape or the fullscreen payload
      contract.

## Out of scope

- Any control over the presentation terminal's window size or the
  Omarchy logo/banner it shows — those are Omarchy-owned, not this
  repo's; if the user wants those configurable, that's a request against
  Omarchy itself, not `omarchy-scripts`.
- Per-keybind overrides beyond what the JSON payload already supports.

## Testing notes

- Toggle the config default both ways and confirm a plain (no-payload)
  `shell toggle` call reflects it.
- Confirm `SUPER + R`'s explicit `{"fullscreen":true}` keybind still works
  regardless of the configured default.

## Report

Fill in when finished: what changed, decisions made, limitations, and
useful follow-ups. Set Status to Done after merge, then move the
completed file to `docs/tasks/done/`.
