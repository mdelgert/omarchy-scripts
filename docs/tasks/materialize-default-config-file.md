# Task: Materialize a default config.json on install so it's discoverable

Status: Ready
Type: feature

## Problem

`~/.config/omarchy-scripts/config.json` does not exist until the first
time something writes a setting (`config set`, `add-dir`, or
`configure-omarchy-scripts.sh` with at least one non-blank field). On a
fresh install there is nothing there — confirmed directly this session:
`~/.config/omarchy-scripts/` only contains an empty `scripts/` directory,
no `config.json`, even though the plugin is installed and has been run.

This makes the settings file hard to find or reason about: a user
looking for "where do my settings live" finds nothing, and
`configure-omarchy-scripts.sh`'s param form shows every field blank with
no visual indication of the actual current values (blank there means
"leave unchanged," which is correct behavior, but is easy to confuse
with "there is no config yet" — see the companion clarification in this
task's Problem statement: script `default=` attributes are static
strings parsed from comments, not live current state, so they cannot be
used to solve this by showing "real" defaults in the form itself).

## Scope

- Make the full default configuration materialize as an actual,
  readable `config.json` file rather than only existing implicitly in
  code (`KEY_ACTION_DEFAULTS`) until first write. Two reasonable
  approaches — pick whichever is cleanest given the current
  `_load_settings()`/`_write_settings()` design, and document the choice
  in the Report:
  - (a) Write a fully-populated `config.json` (every key action from
    `KEY_ACTION_DEFAULTS` plus an empty `scriptDirs: []`) the first time
    `_load_settings()` runs and finds no file — i.e. lazily materialize
    on first read, not just first write.
  - (b) Add an explicit `omarchy-scripts config init` CLI command that
    writes the fully-populated defaults file, and call it (or have it be
    a no-op if the file already exists) from `omarchy-plugin/install.sh`
    so a freshly installed plugin already has a discoverable file.
  Either way, writing over an *existing* file's already-customized
  values must never happen — only fill in what's genuinely missing.
- Make the file's location easy to find without reading source: print
  `configPath` prominently (this already happens in `config get/set`
  JSON output — confirm it's equally visible from
  `configure-omarchy-scripts.sh`'s printed output, which already
  includes it) and mention the exact path
  (`~/.config/omarchy-scripts/config.json`, or
  `$XDG_CONFIG_HOME/omarchy-scripts/config.json` when set) in
  `README.md`.
- Do **not** attempt to make `@param default=` values in
  `configure-omarchy-scripts.sh` dynamically reflect current settings —
  confirm in the Report that this remains a static, comment-parsed
  mechanism per `docs/SCRIPT_SPEC.md`, and that showing live current
  values in the form is a separate, larger frontend/engine capability
  (dynamic per-invocation defaults) not undertaken here. If it seems
  small enough to do safely, note that as a follow-up suggestion instead
  of scope-creeping this task.

## What done looks like

- [ ] A fresh install (no prior `config.json`) results in a real,
      readable `config.json` containing every key action's default value
      and an empty `scriptDirs` array, without the user having to change
      anything first.
- [ ] An existing customized `config.json` is left untouched by whatever
      mechanism does this (no accidental overwrite of a real user
      customization).
- [ ] `README.md` states the exact config file path plainly enough that
      "where do my settings live" is answerable by reading the README,
      not the source.
- [ ] Tests are added or updated where behavior changed.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the
      project's definition of done.

## Out of scope

- Dynamic/live default values shown in `configure-omarchy-scripts.sh`'s
  param form — flagged above as a separate, larger capability.
- Any change to what the defaults themselves are (`KEY_ACTION_DEFAULTS`
  values stay the same).

## Testing notes

- Delete/rename any existing `config.json` (in an isolated
  `XDG_CONFIG_HOME`, not the real one) and confirm the chosen mechanism
  produces a fully-populated file with the same values
  `resolve_key_bindings()` already falls back to today.
- Confirm running against an **existing**, customized `config.json` does
  not add back removed/overridden keys or otherwise change values that
  were already there.
- Confirm `configure-omarchy-scripts.sh`'s printed output (and
  `config get`/`config list-dirs`) already surfaces the file's path
  clearly; if not, fix that as part of this task.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
