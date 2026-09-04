# Task: Full shell restart after install, plus a matching uninstall.sh

Status: Ready
Type: feature

## Problem

`omarchy-plugin/install.sh` ends by calling `omarchy-shell shell rescanPlugins`,
which hot-reloads plugin QML in the running shell. That is not reliable for
every kind of change: while live-testing the `duplicate-script-with-new-id`
task (see its Report in `docs/tasks/done/`), a structural QML layout change
(`Row` → `Flow` in `Menu.qml`) did not take visible effect after
`rescanPlugins` — the menu kept showing the old, buggy layout even though the
file on disk was correct and `qmllint` was clean. Only a full
`omarchy-restart-shell` picked it up. A developer iterating on this plugin
via `install.sh` (the documented dev-loop entry point, see
`docs/tasks/done/reinstall-from-source.md` and this repo's own
`reinstall-from-source` script) has no reliable signal that they need to
additionally run `omarchy-restart-shell` by hand after every install — it is
easy to conclude a real change "isn't working" when it is actually just
sitting behind a stale hot-reload.

Separately, there is no scripted counterpart to `install.sh`. A developer who
installed this plugin via the dev-install path
(`omarchy-plugin/install.sh`, which `rsync`s the working tree directly into
`~/.config/omarchy/plugins/io.github.mdelgert.omarchy-scripts` rather than
git-cloning it) has no single documented command to cleanly remove it again;
today that means manually figuring out `omarchy-plugin-remove` and/or
deleting the plugin folder and workspace/settings files by hand, with no
review of what will be deleted before it happens.

## Scope

- `omarchy-plugin/install.sh`: after the existing `rescanPlugins` hot-reload
  step, additionally call `omarchy-restart-shell` (guarded the same way
  `rescanPlugins` already is — `command -v` check, non-fatal on failure with
  a clear stderr message, since running outside a live session is an
  expected, supported case for this script). Update the script's own header
  comment and the final "Enable and open it with" instructions if the
  restart changes what a caller needs to do next.
- Add `omarchy-plugin/uninstall.sh`, the developer-facing counterpart to
  `install.sh`:
  - Removes the installed plugin at
    `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.mdelgert.omarchy-scripts`
    — prefer shelling out to the existing `omarchy-plugin-remove` (see
    `docs/ARCHITECTURE.md`'s "the CLI is a thin JSON interface" pattern:
    reuse existing Omarchy tooling rather than reimplementing plugin removal)
    if it is available, falling back to a direct, clearly-scoped `rm -rf` of
    that one plugin directory (never a path outside it) if not.
  - Calls `omarchy-restart-shell` afterward the same way `install.sh` does,
    so the shell stops showing the plugin immediately rather than only after
    a manual restart.
  - Does **not** delete the user's workspace scripts
    (`${OMARCHY_SCRIPTS_HOME:-${XDG_CONFIG_HOME:-~/.config}/omarchy-scripts}`)
    or settings file by default — uninstalling the plugin binary/UI should
    not silently destroy a developer's own scripts or `devSourcePath`/`keys`
    customizations. Offer this as an explicit opt-in flag (e.g.
    `--purge-workspace`) if implemented, clearly documented as destructive,
    never the default.
  - Prints what it removed (and, for `--purge-workspace` if added, what
    workspace path it deleted), mirroring `install.sh`'s own
    "installed ... -> ..." style status output.
- Update `README.md`'s "Quick start (development)" section (or wherever
  `install.sh` is currently documented) to mention `uninstall.sh` alongside
  it.

## What done looks like

- [ ] Running `omarchy-plugin/install.sh` inside a live Omarchy/Hyprland
      session ends with a full shell restart, not just a `rescanPlugins`
      hot-reload — confirmed by making a structural QML change (e.g.
      reordering an existing action button) and seeing it take effect
      without a manual `omarchy-restart-shell` afterward.
- [ ] Running `install.sh` outside a live session (no compositor) still
      completes successfully; the new restart step fails non-fatally with a
      clear message, the same way the existing `rescanPlugins` step already
      does.
- [ ] `omarchy-plugin/uninstall.sh` removes the installed plugin directory
      and restarts the shell so it disappears from a running menu/bar
      immediately.
- [ ] `uninstall.sh` never touches the user's workspace scripts or
      `config.json` unless an explicit, documented, non-default flag is
      passed.
- [ ] Tests are added or updated where behavior changed (if any of this
      logic moves into something `tests/test_core.py` can exercise; a pure
      shell-script change may instead need a documented manual test in the
      Report, per this repo's existing shell-script scripts having no
      Python-level test coverage of their own body).
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [ ] `README.md` (and `docs/ARCHITECTURE.md` if it starts describing
      `uninstall.sh` as part of the dev workflow) documents the new script.

## Out of scope

- Any change to the *packaged*/non-dev install path
  (`omarchy plugin add https://github.com/mdelgert/omarchy-scripts.git`),
  which is unaffected by this task — `install.sh`/`uninstall.sh` are the
  working-tree-copy developer path only, per `install.sh`'s own existing
  header comment.
- Changing what `omarchy-restart-shell` itself does, or when Omarchy's
  session decides a full shell restart vs. a plugin rescan is warranted in
  general — this task only adds an unconditional restart call to this
  plugin's own install/uninstall scripts.
- Building any interactive confirmation UI for `uninstall.sh` beyond a
  plain `--purge-workspace`-style flag, if implemented; a destructive
  workspace purge should require an explicit flag, not a prompt this script
  has to build itself.

## Testing notes

- In a real Omarchy/Hyprland session: make a small, structural QML edit
  (e.g. swap the order of two action buttons), run
  `omarchy-plugin/install.sh`, and confirm the change is visible in the
  running menu without a separate manual `omarchy-restart-shell` call.
- Run `install.sh` with no Hyprland session reachable (e.g. via `env -u
  HYPRLAND_INSTANCE_SIGNATURE`) and confirm it still exits 0, printing a
  clear non-fatal message for the restart step instead of failing the whole
  script.
- Run `omarchy-plugin/uninstall.sh` after an `install.sh`; confirm the
  plugin folder is gone, the shell restarts, and the menu no longer offers
  the "Scripts" entry until reinstalled.
- Confirm workspace scripts (`~/.config/omarchy-scripts/scripts/*.sh`) and
  `~/.config/omarchy-scripts/config.json` still exist after a default
  `uninstall.sh` run.

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
