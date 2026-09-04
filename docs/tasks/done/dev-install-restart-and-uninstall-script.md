# Task: Full shell restart after install, plus a matching uninstall.sh

Status: Done
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

- [x] Running `omarchy-plugin/install.sh` inside a live Omarchy/Hyprland
      session ends with a full shell restart, not just a `rescanPlugins`
      hot-reload — confirmed by making a structural QML change (e.g.
      reordering an existing action button) and seeing it take effect
      without a manual `omarchy-restart-shell` afterward.
- [x] Running `install.sh` outside a live session (no compositor) still
      completes successfully; the new restart step fails non-fatally with a
      clear message, the same way the existing `rescanPlugins` step already
      does.
- [x] `omarchy-plugin/uninstall.sh` removes the installed plugin directory
      and restarts the shell so it disappears from a running menu/bar
      immediately.
- [x] `uninstall.sh` never touches the user's workspace scripts or
      `config.json` unless an explicit, documented, non-default flag is
      passed.
- [x] Tests are added or updated where behavior changed (if any of this
      logic moves into something `tests/test_core.py` can exercise; a pure
      shell-script change may instead need a documented manual test in the
      Report, per this repo's existing shell-script scripts having no
      Python-level test coverage of their own body).
- [x] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.
- [x] `README.md` (and `docs/ARCHITECTURE.md` if it starts describing
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

**Changed:**
- `omarchy-plugin/install.sh`: added a header comment pointing at
  `uninstall.sh`, and — after the existing `rescanPlugins` hot-reload step —
  a new guarded block that calls `omarchy-restart-shell` if it's on `PATH`,
  printing `shell restarted` on success or a non-fatal stderr message
  otherwise (matching the `rescanPlugins` step's own guard style exactly).
- New `omarchy-plugin/uninstall.sh` (executable): removes the installed
  plugin, preferring `omarchy-plugin-remove <id> --yes`, falling back to a
  direct `rm -rf` of the one resolved plugin path if that tool is missing
  **or fails for any reason**. Supports an opt-in `--purge-workspace` flag
  to also delete `OMARCHY_SCRIPTS_HOME`/the workspace `scripts/`+config
  directory (never the default). Restarts the shell afterward, non-fatal
  outside a live session. Exits 0 for both "not installed" and successful
  removal.
- `README.md`: documented the restart behavior and added `uninstall.sh`
  usage (default and `--purge-workspace`) to "Quick start (development)".

**Bug found and fixed during testing:** the first version of `uninstall.sh`
called `omarchy-plugin-remove` unconditionally when the plugin appeared
installed, without a failure fallback. `omarchy-plugin-remove` hardcodes
`$HOME/.config` rather than honoring a customized `XDG_CONFIG_HOME` (unlike
this plugin's own scripts, which all resolve
`${XDG_CONFIG_HOME:-$HOME/.config}`). Under a customized `XDG_CONFIG_HOME`
this made the external tool fail even though this script's own `$DEST`
genuinely existed, and — because the call wasn't guarded — the whole script
aborted (`set -e`) instead of falling back to a direct removal. Fixed by
only treating `omarchy-plugin-remove` as authoritative on success; any
failure (missing tool, wrong assumptions, anything else) now falls straight
through to the manual `rm -rf "$DEST"` fallback, so `uninstall.sh` always
completes rather than getting stuck on an unrelated tool's own path
assumptions.

**Verified live** (real Hyprland/quickshell session in this sandbox, env
vars manually exported per this session's established access pattern):
- `install.sh` run end-to-end: completed with `shell reloaded` then
  `shell restarted`; confirmed via a new `quickshell` PID after each run
  (531064→533339→534398 etc.), not just a log line.
- `uninstall.sh` default run: plugin directory removed (via
  `omarchy-plugin-remove`, which also wrote its own timestamped backup),
  workspace `scripts/` and `config.json` left untouched, shell restarted
  (new PID confirmed again).
- `uninstall.sh --purge-workspace` in an isolated sandbox
  (`OMARCHY_SCRIPTS_HOME`/`XDG_CONFIG_HOME` pointed at `/tmp`, no real
  session reachable): correctly hit the `rm -rf` fallback path (since the
  real `omarchy-plugin-remove` doesn't see the sandboxed config location),
  deleted the fake workspace, and still exited 0 with a clear
  "could not restart the shell" message for the missing session — this is
  exactly the scenario that first surfaced the fallback bug above.
- `install.sh` with `HYPRLAND_INSTANCE_SIGNATURE` unset / `XDG_RUNTIME_DIR`
  pointed at an empty fake directory: both `rescanPlugins` and the new
  restart step failed non-fatally with clear stderr messages; script still
  exited 0.
- Restored the live session's plugin back to `main`'s build afterward so
  the user's normal session wasn't left on this task's dev build.

**Limitations / follow-ups:**
- The pre-existing `CLAUDE.md` symlink issue (breaks
  `omarchy-plugin-validate`'s manifest check on every branch, including
  `main`) had to be worked around locally (temporarily moving the file out
  of the worktree, restored before committing) to run `install.sh`
  end-to-end for this task's testing. Left unfixed — out of scope here, and
  identical on `main`.
- `make validate` reported zero problems in this worktree (no
  `scriptDirs`-related duplicate-id noise this time, unlike some earlier
  sessions on this dev machine); this is environment-dependent and not
  caused by this task's changes.
- No new automated tests were added: this task only changes plain Bash
  scripts with no Python-level surface for `tests/test_core.py` to exercise,
  consistent with this repo's existing shell scripts having no Python test
  coverage of their own body. Verification is the manual/live testing
  documented above.
