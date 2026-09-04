# Task: stop shipping a symlink that breaks `omarchy plugin add`

Status: In progress
Type: bug

## Problem

Installing this repo the normal, documented way — `omarchy plugin add
https://github.com/mdelgert/omarchy-scripts.git --enable` (the exact command
in `README.md`'s Install section) — fails on a fresh machine with:

```
omarchy-plugin-validate: symlinks are not allowed inside a plugin folder: /home/mdelgert/.config/omarchy/plugins/.add.tmp.995150/CLAUDE.md
omarchy-plugin-add: refusing to add: validation failed
```

`CLAUDE.md` (added in commit `7f35d14`, "docs: add CLAUDE.md as a symlink to
AGENTS.md") is a real symlink to `AGENTS.md`, tracked as such in git — so
`omarchy plugin add` (Omarchy's own git-clone-then-validate installer) always
clones a symlink into the plugin folder, and Omarchy's own
`omarchy-plugin-validate` rejects any symlink inside a plugin folder,
unconditionally. This is not a corner case: it reproduces on any machine
that has never had this repo cloned before, i.e. exactly the documented,
primary install path every new user is expected to follow.

A prior fix (commits `c687b58`/`fe19e60`, "fix(install.sh): exclude
CLAUDE.md symlink from installed plugin copy") only patched
`omarchy-plugin/install.sh`'s own `rsync --exclude` list — that fixes the
*developer* install path (`./omarchy-plugin/install.sh`, which controls its
own copy step) but does nothing for `omarchy plugin add`, which is Omarchy's
own tool, out of this repo's control, cloning the raw repository as-is. The
symlink itself is the root cause and needs to stop existing as a tracked
symlink, not just be excluded by one of the two install paths.

## Scope

- Stop tracking `CLAUDE.md` as a git symlink. Concretely, one of:
  - Replace it with a normal (non-symlink) file. If its whole purpose is
    "Claude Code auto-discovers `CLAUDE.md`, and `AGENTS.md` is the actual
    source of truth other tools/humans read", either duplicate the content
    as a plain file (accept the duplication, and add a cheap guard — a
    `make test`-run check or similar — that fails loudly if `CLAUDE.md`
    and `AGENTS.md` drift apart), or make `AGENTS.md` itself the symlink
    target of a *plain-file* `CLAUDE.md` that never leaves the repo as a
    filesystem symlink either way.
  - Or stop committing `CLAUDE.md` at all: `.gitignore` it, and instead
    document (in `AGENTS.md`/a dev-setup note) that a contributor who wants
    Claude Code's auto-discovery can create the symlink locally themselves
    (`ln -s AGENTS.md CLAUDE.md`) — it would then never be part of what
    `omarchy plugin add` clones.
  - Pick whichever keeps a single source of truth with the least ongoing
    maintenance burden; explain the choice in the Report.
- Remove the now-unnecessary `--exclude 'CLAUDE.md'` line from
  `omarchy-plugin/install.sh` if the chosen fix makes it redundant (e.g. if
  `CLAUDE.md` is no longer a symlink, or no longer committed at all) —
  don't leave dead exclusions around. If it's still committed as a plain
  file, decide whether excluding it from the installed copy is still
  desirable (a plain file doesn't break `omarchy-plugin-validate` the way a
  symlink does, so this exclusion may no longer be needed at all).
- Verify `omarchy plugin add https://github.com/mdelgert/omarchy-scripts.git
  --enable` actually succeeds end-to-end against the fixed `main` branch —
  this is the exact reproduction the bug report used, so it's the right
  acceptance test, not just `omarchy-plugin-validate` in isolation.
- In `README.md`, move (or duplicate, if that reads better) the existing
  "### Remove" section (`omarchy plugin disable`/`omarchy plugin remove
  --yes`) to sit immediately after the Install section's own command block,
  so a new reader sees how to install *and* how to cleanly remove it
  together, before scrolling past keybinding/update/troubleshooting content
  that currently sits between them. Keep the existing content and wording;
  this is a reordering/visibility fix, not a rewrite. The
  `omarchy-plugin/uninstall.sh` development-uninstall mention can stay
  where it is next to `install.sh` in "Quick start (development)" — this
  reordering is about the primary, non-dev install/remove pair at the top
  of the README.

## What done looks like

- [ ] `omarchy plugin add https://github.com/mdelgert/omarchy-scripts.git
      --enable` succeeds on a machine/checkout that has never had this repo
      before (or the closest available equivalent — e.g. a fresh temp
      `HOME`/plugin dir — if a truly separate machine isn't available;
      document exactly what was tested in the Report either way).
- [ ] No symlink is committed anywhere under the repo root that would end
      up inside a cloned/installed plugin folder.
- [ ] `./omarchy-plugin/install.sh` (the dev path) still works exactly as
      before — no regression to the path the previous partial fix was
      protecting.
- [ ] README's install and remove commands are adjacent, so a reader sees
      both without scrolling past unrelated content.
- [ ] `make test`, `make lint-qml`, and `make validate` meet the project's
      definition of done.

## Out of scope

- Any change to Omarchy's own `omarchy-plugin-validate`/`omarchy plugin
  add` — they are correct to reject symlinks; this task fixes this repo's
  side, not Omarchy's validation rule.
- Removing Claude Code auto-discovery entirely as a concept, if a
  no-symlink way to keep it is reasonably cheap (see Scope options) —
  only drop it outright if every symlink-free option is clearly worse.
- Any other README restructuring beyond moving/duplicating the Remove
  section next to Install.

## Testing notes

- Reproduce first: on `main` before the fix, run (or simulate) `omarchy
  plugin add https://github.com/mdelgert/omarchy-scripts.git --enable`
  against a clean plugin directory and confirm the exact
  `omarchy-plugin-validate: symlinks are not allowed` failure from the bug
  report.
- After the fix, confirm the same command succeeds, the plugin is usable
  (bar icon appears, menu opens), and `git ls-files -s` (or `find -type l`)
  shows no symlinks under the repo.
- Confirm `./omarchy-plugin/install.sh` still installs cleanly (this is
  the path the earlier partial fix targeted; don't regress it).

## Report

Fill in when finished: what changed, decisions made, limitations, and useful follow-ups. Set Status to Done after merge, then move the completed file to `docs/tasks/done/`.
